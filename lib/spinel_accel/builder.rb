# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'shellwords'

module SpinelAccel
  class Builder
    CRUBY_64BIT = RUBY_ENGINE == 'ruby' && [0].pack('J').bytesize == 8
    private_constant :CRUBY_64BIT

    def initialize(kernel, spinel_root: ENV['SPINEL_ROOT'])
      @kernel = kernel
      @spinel_root = spinel_root && File.expand_path(spinel_root)
      @store = ArtifactStore.new(kernel)
    end

    def self.doctor(spinel_root: ENV['SPINEL_ROOT'])
      compiler = spinel_root && File.join(File.expand_path(spinel_root), 'bin/spinel')
      checks = { 'cruby_64bit' => CRUBY_64BIT,
                 'ruby_headers' => File.file?(File.join(RbConfig::CONFIG.fetch('rubyhdrdir'), 'ruby.h')),
                 'runtime_sources' => !!(spinel_root && File.file?(File.join(spinel_root, 'lib/sp_gc.c'))) }
      checks['compiler_pin'] = compiler_pinned?(compiler)
      checks['cc'] = tool_available?(RbConfig::CONFIG.fetch('CC'))
      checks['make'] = tool_available?(ENV.fetch('MAKE', 'make'))
      { 'ok' => checks.values.all? { |v| v == true }, 'checks' => checks, 'abi' => SpinelAccel.abi, 'spinel_pin' => PIN }
    end

    def self.compiler_pinned?(compiler)
      return false unless compiler && File.executable?(compiler)
      result = Command.run([compiler, '--version'], timeout: 10)
      result['exit'] == 0 && !result['timeout'] && result['output'].include?(PIN)
    end

    def self.tool_available?(command)
      Command.run(Shellwords.split(command) + ['--version'], timeout: 10)['exit'] == 0
    rescue Errno::ENOENT
      false
    end
    private_class_method :compiler_pinned?, :tool_available?

    def emit
      report = self.class.doctor(spinel_root: @spinel_root)
      raise BuildError, "toolchain check failed: #{JSON.generate(report)}" unless report['ok']
      with_lock do
        Dir.mktmpdir('emit-', @kernel.root) do |stage|
          compiler = File.join(@spinel_root, 'bin/spinel')
          version = Command.run!([compiler, '--version'], dir: stage, log: log)['output'].strip
          bridge = "SpinelAccelExport#{@kernel.fingerprint}"
          wrappers = @kernel.entries.map do |entry, spec|
            params = spec['params'].each_index.map { |i| "arg#{i}" }.join(', ')
            "def self.#{entry}(#{params}); #{@kernel.module_name}.#{entry}(#{params}); end"
          end.join("\n")
          driver = @kernel.entries.map do |entry, spec|
            "p #{bridge}.#{entry}(#{spec['params'].map { |t| Contract.seed(t) }.join(', ')})"
          end.join("\n")
          File.write(File.join(stage, 'kernel.rb'), @kernel.source_text + "\nmodule #{bridge}\n#{wrappers}\nend\nif __FILE__ == $0\n#{driver}\nend\n")
          Command.run!([compiler, File.join(stage, 'kernel.rb'), '-c', '--no-line-map', '--require-gate',
                        '--ext', 'cruby', '--ext-init', "spx_init_#{@kernel.feature}",
                        '--ext-entry', @kernel.entries.keys.map { |m| "#{bridge}.#{m}" }.join(','),
                        '-o', File.join(stage, "#{@kernel.feature}.c")], dir: stage, log: log)
          # Give every compiled kernel its own Ruby module. The reference stays
          # in an anonymous scope; loading native code never overwrites it.
          shim = File.join(stage, "#{@kernel.feature}_ext.c")
          text = File.read(shim)
          needle = "rb_define_module(\"#{bridge}\")"
          raise BuildError, 'compiler shim format changed; no module registration found' unless text.scan(needle).length == @kernel.entries.length
          File.write(shim, text.gsub(needle, "rb_define_module(\"#{@kernel.native_constant}\")"))
          runtime = File.join(@spinel_root, 'lib')
          %w[*.c *.h regexp/*.c regexp/*.h regexp/*.inc regexp/shim/*.h].flat_map { |pattern| Dir[File.join(runtime, pattern)] }.each { |path| FileUtils.cp(path, stage) }
          FileUtils.cp_r(File.join(runtime, 'regexp/shim/mruby'), stage)
          FileUtils.cp(File.join(@spinel_root, 'LICENSE'), File.join(stage, 'SPINEL_LICENSE'))
          @store.publish_bundle(stage, compiler_sha256: Digest::SHA256.file(compiler).hexdigest, compiler_version: version)
        end
      end
    end

    def build
      compile(bundle: emit)
    end

    def compile(bundle:)
      raise BuildError, 'native builds require 64-bit CRuby' unless CRUBY_64BIT
      bundle = File.expand_path(bundle)
      with_lock do
        Dir.mktmpdir('compile-', @kernel.root) do |stage|
          metadata = @store.extract_bundle(bundle, into: stage)
          File.write(File.join(stage, 'exports.map'), "{ global: Init_#{@kernel.feature}; local: *; };\n")
          File.write(File.join(stage, 'extconf.rb'), extconf)
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          Command.run!([RbConfig.ruby, 'extconf.rb'], dir: stage, log: log)
          Command.run!(Shellwords.split(ENV.fetch('MAKE', 'make')) + ['-j8'], dir: stage, log: log)
          @store.install(stage, bundle: bundle, metadata: metadata,
                         build_seconds: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(3))
        end
      end
    rescue JSON::ParserError, KeyError, Errno::ENOENT => e
      raise ArtifactError, "invalid source bundle: #{e.message}"
    end

    private

    def with_lock
      FileUtils.mkdir_p(@kernel.root)
      File.open(File.join(@kernel.root, 'build.lock'), 'a') do |lock|
        lock.flock(File::LOCK_EX)
        yield
      end
    end

    def log
      File.join(@kernel.root, 'build.log')
    end

    def extconf
      exported = "Init_#{@kernel.feature}"
      <<~RUBY
        require 'mkmf'
        $INCFLAGS << ' -I$(srcdir)'
        $CFLAGS << ' -O2 -std=gnu11 -ffp-contract=off'
        $libs << ' -lm -lpthread'
        if RbConfig::CONFIG['host_os'].include?('darwin')
          $LDFLAGS << ' -Wl,-exported_symbol,_#{exported}'
        else
          $LDFLAGS << ' -Wl,-Bsymbolic-functions -Wl,--version-script=$(srcdir)/exports.map'
        end
        create_makefile('#{@kernel.feature}')
      RUBY
    end
  end
end

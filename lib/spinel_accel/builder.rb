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
    end

    def self.doctor(spinel_root: ENV['SPINEL_ROOT'])
      compiler = spinel_root && File.join(File.expand_path(spinel_root), 'bin/spinel')
      checks = { 'cruby_64bit' => CRUBY_64BIT,
                 'ruby_headers' => File.file?(File.join(RbConfig::CONFIG.fetch('rubyhdrdir'), 'ruby.h')),
                 'runtime_sources' => !!(spinel_root && File.file?(File.join(spinel_root, 'lib/sp_gc.c'))) }
      compiler_result = compiler && File.executable?(compiler) && Command.run([compiler, '--version'], timeout: 10)
      checks['compiler_pin'] = !!(compiler_result && compiler_result['exit'] == 0 && !compiler_result['timeout'] && compiler_result['output'].include?(PIN))
      %w[CC MAKE].each do |name|
        command = name == 'CC' ? RbConfig::CONFIG.fetch('CC') : ENV.fetch('MAKE', 'make')
        begin
          checks[name.downcase] = Command.run(Shellwords.split(command) + ['--version'], timeout: 10)['exit'] == 0
        rescue Errno::ENOENT
          checks[name.downcase] = false
        end
      end
      { 'ok' => checks.values.all? { |v| v == true }, 'checks' => checks, 'abi' => SpinelAccel.abi, 'spinel_pin' => PIN }
    end

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
          files = Dir[File.join(stage, '**/*')].select { |p| File.file?(p) }.sort.to_h do |path|
            [path.delete_prefix(stage + '/'), Digest::SHA256.file(path).hexdigest]
          end
          metadata = { 'format' => 1, 'fingerprint' => @kernel.fingerprint, 'spinel_pin' => PIN,
                       'compiler_sha256' => Digest::SHA256.file(compiler).hexdigest, 'compiler_version' => version,
                       'files' => files }
          File.write(File.join(stage, 'source.json'), JSON.pretty_generate(metadata) + "\n")
          key = Digest::SHA256.file(File.join(stage, 'source.json')).hexdigest
          destination = File.join(@kernel.root, 'bundles', key)
          FileUtils.mkdir_p(File.dirname(destination))
          FileUtils.cp_r(stage, destination) unless File.exist?(destination)
          destination
        end
      end
    end

    def build
      compile(bundle: emit)
    end

    def compile(bundle:)
      raise BuildError, 'native builds require 64-bit CRuby' unless CRUBY_64BIT
      bundle = File.expand_path(bundle)
      metadata = JSON.parse(File.read(File.join(bundle, 'source.json')))
      unless metadata.fetch('format') == 1 && metadata.fetch('fingerprint') == @kernel.fingerprint && metadata.fetch('spinel_pin') == PIN
        raise ArtifactError, 'source bundle belongs to a different kernel or compiler pin'
      end
      files = metadata.fetch('files')
      required = ["#{@kernel.feature}.c", "#{@kernel.feature}_ext.c", "#{@kernel.feature}.h", 'sp_gc.c', 'spinel_rt.h', 'SPINEL_LICENSE']
      raise ArtifactError, 'source bundle is incomplete' unless (required - files.keys).empty?
      files.each do |path, hash|
        unless path.match?(/\A[\w.\/-]+\z/) && !path.split('/').include?('..') && !path.start_with?('/') &&
               File.file?(File.join(bundle, path)) && !File.symlink?(File.join(bundle, path)) && Digest::SHA256.file(File.join(bundle, path)).hexdigest == hash
          raise ArtifactError, "source bundle checksum/path mismatch: #{path}"
        end
      end
      with_lock do
        Dir.mktmpdir('compile-', @kernel.root) do |stage|
          files.each_key do |path|
            target = File.join(stage, path)
            FileUtils.mkdir_p(File.dirname(target))
            FileUtils.cp(File.join(bundle, path), target)
          end
          File.write(File.join(stage, 'exports.map'), "{ global: Init_#{@kernel.feature}; local: *; };\n")
          File.write(File.join(stage, 'extconf.rb'), extconf)
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          Command.run!([RbConfig.ruby, 'extconf.rb'], dir: stage, log: log)
          Command.run!(Shellwords.split(ENV.fetch('MAKE', 'make')) + ['-j8'], dir: stage, log: log)
          extension = "#{@kernel.feature}.#{RbConfig::CONFIG.fetch('DLEXT')}"
          sha = Digest::SHA256.file(File.join(stage, extension)).hexdigest
          target = File.join(@kernel.root, 'native', SpinelAccel.abi_key, sha)
          FileUtils.mkdir_p(target)
          FileUtils.cp(File.join(stage, extension), File.join(target, extension)) unless File.exist?(File.join(target, extension))
          FileUtils.cp(File.join(stage, 'SPINEL_LICENSE'), target)
          build = metadata.reject { |key, _| key == 'files' }.merge('abi' => SpinelAccel.abi,
            'extension_sha256' => sha, 'gem_version' => VERSION, 'ruby' => RUBY_DESCRIPTION,
            'source_bundle_sha256' => Digest::SHA256.file(File.join(bundle, 'source.json')).hexdigest,
            'build_seconds' => (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(3))
          File.write(File.join(target, 'build.json'), JSON.pretty_generate(build) + "\n")
          pointer = File.join(File.dirname(target), 'current.json')
          temporary = "#{pointer}.#{Process.pid}.tmp"
          File.write(temporary, JSON.generate('artifact' => sha) + "\n")
          File.rename(temporary, pointer)
          target
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

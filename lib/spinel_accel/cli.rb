# frozen_string_literal: true

require 'optparse'
require_relative '../spinel_accel'

module SpinelAccel
  class CLI
    def self.run(argv)
      new.run(argv)
    end

    def run(argv)
      args = argv.dup
      command = args.shift
      if %w[--version -h --help].include?(command)
        args.unshift(command)
        command = nil
      end
      options = { config: 'spinel_accel.rb', warmup: 50, rounds: 7, target_ms: 30 }
      parser = OptionParser.new do |p|
        p.banner = 'Usage: spinel-accel init DIR | doctor | build|emit|compile|check|bench [NAME] [options]'
        p.on('--config FILE') { |v| options[:config] = v }
        p.on('--spinel-root DIR') { |v| options[:spinel_root] = v }
        p.on('--bundle DIR') { |v| options[:bundle] = v }
        p.on('--cache-dir DIR') { |v| ENV['SPINEL_ACCEL_CACHE'] = File.expand_path(v) }
        p.on('--warmup N', Integer) { |v| options[:warmup] = v }
        p.on('--rounds N', Integer) { |v| options[:rounds] = v }
        p.on('--target-ms N', Float) { |v| options[:target_ms] = v }
        p.on('--version') { puts VERSION; return 0 }
        p.on('-h', '--help') { puts p; return 0 }
      end
      parser.parse!(args)
      unless %w[init doctor build emit compile check bench].include?(command)
        puts parser
        return command.nil? ? 0 : 1
      end
      raise ConfigurationError, 'too many positional arguments' if args.length > 1
      root = options.fetch(:spinel_root, ENV['SPINEL_ROOT'])
      if command == 'init'
        init(args.fetch(0) { raise ConfigurationError, 'init requires a new directory' })
      elsif command == 'doctor'
        result = Builder.doctor(spinel_root: root)
        puts JSON.pretty_generate(result)
        return result['ok'] ? 0 : 1
      else
        load File.expand_path(options[:config])
        kernels = SpinelAccel.kernels
        selected = args.empty? ? kernels.values : [kernels.fetch(args[0]) { raise ConfigurationError, "unknown kernel: #{args[0]}" }]
        raise ConfigurationError, 'no kernels registered' if selected.empty?
        results = selected.map do |kernel|
          builder = Builder.new(kernel, spinel_root: root)
          case command
          when 'build' then { 'kernel' => kernel.name, 'artifact' => builder.build }
          when 'emit' then { 'kernel' => kernel.name, 'bundle' => builder.emit }
          when 'compile'
            raise ConfigurationError, 'compile needs --bundle DIR and one kernel name' unless options[:bundle] && selected.length == 1
            { 'kernel' => kernel.name, 'artifact' => builder.compile(bundle: options[:bundle]) }
          when 'check' then { 'kernel' => kernel.name, 'verified_cases' => kernel.check! }
          when 'bench' then Benchmark.new(kernel).run(**options.slice(:warmup, :rounds, :target_ms))
          end
        end
        puts JSON.pretty_generate(results)
      end
      0
    rescue Error, OptionParser::ParseError, Errno::ENOENT, KeyError => e
      warn "spinel-accel: #{e.class}: #{e.message}"
      1
    end

    private

    def init(dir)
      raise ConfigurationError, "directory already exists: #{dir}" if File.exist?(dir)
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, 'kernel.rb'), <<~'RUBY')
        module DemoKernel
          def self.sum(values)
            total = 0
            values.each { |value| total += value }
            total
          end
        end
      RUBY
      File.write(File.join(dir, 'spinel_accel.rb'), <<~'RUBY')
        require 'spinel_accel'
        SpinelAccel.register :demo,
          source: File.expand_path('kernel.rb', __dir__), module_name: 'DemoKernel',
          entries: { sum: { params: [:integer_array], returns: :integer } },
          samples: { sum: [ [[1, 2, 3]], [[]], [[-10, 2, 8]] ] }
      RUBY
      File.write(File.join(dir, '.gitignore'), ".spinel_accel/\n")
      puts JSON.generate('created' => File.expand_path(dir))
    end
  end
end

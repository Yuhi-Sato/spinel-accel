# frozen_string_literal: true

require 'thread'

module SpinelAccel
  class Kernel
    attr_reader :name, :source, :source_text, :module_name, :entries, :samples, :cache_dir, :fingerprint

    def initialize(name:, source:, module_name:, entries:, samples: {}, cache_dir: ENV.fetch('SPINEL_ACCEL_CACHE', '.spinel_accel'))
      @name = name.to_s.dup.freeze
      @module_name = module_name.to_s.dup.freeze
      unless @name.match?(/\A[a-zA-Z][a-zA-Z0-9_-]*\z/) && @module_name.match?(/\A[A-Z]\w*(?:::[A-Z]\w*)*\z/)
        raise ConfigurationError, 'invalid kernel name or module_name'
      end
      @source = File.expand_path(source).freeze
      @source_text = File.read(@source).freeze
      @entries = entries.to_h.sort_by { |key, _| key.to_s }.to_h do |key, value|
        method = key.to_s.dup.freeze
        raise ConfigurationError, "invalid entry: #{method}" unless method.match?(/\A[a-z_]\w*\z/)
        spec = value.transform_keys(&:to_sym)
        [method, { 'params' => spec.fetch(:params).map { |t| Contract.validate_type!(t) }.freeze,
                   'returns' => Contract.validate_type!(spec.fetch(:returns)) }.freeze]
      end.freeze
      raise ConfigurationError, 'entries cannot be empty' if @entries.empty?
      @samples = samples.to_h.to_h do |key, cases|
        [key.to_s.dup.freeze, cases.map { |args| Contract.frozen_copy(args) }.freeze]
      end.freeze
      @cache_dir = File.expand_path(cache_dir).freeze
      @fingerprint = Digest::SHA256.hexdigest(JSON.generate({ 'gem' => VERSION, 'pin' => PIN,
        'name' => @name, 'source' => Digest::SHA256.hexdigest(@source_text), 'module' => @module_name, 'entries' => @entries })).freeze
      @mutex = Mutex.new
    end

    def root
      File.join(cache_dir, fingerprint)
    end

    def feature
      "spinel_accel_#{fingerprint[0, 24]}"
    end

    def native_constant
      "SpinelAccelNative#{fingerprint}"
    end

    def ruby_method(entry)
      @mutex.synchronize do
        unless @ruby_module
          scope = Module.new
          scope.module_eval(source_text, source, 1)
          @ruby_module = module_name.split('::').reduce(scope) { |mod, key| mod.const_get(key, false) }
        end
        @ruby_module.method(entry.to_s)
      end
    end

    def artifact
      base = File.join(root, 'native', SpinelAccel.abi_key)
      pointer = JSON.parse(File.read(File.join(base, 'current.json')))
      id = pointer.fetch('artifact')
      raise ArtifactError, 'invalid artifact identifier' unless id.match?(/\A[0-9a-f]{64}\z/)
      dir = File.join(base, id)
      metadata = JSON.parse(File.read(File.join(dir, 'build.json')))
      unless metadata.fetch('fingerprint') == fingerprint && metadata.fetch('abi') == SpinelAccel.abi && metadata.fetch('spinel_pin') == PIN
        raise ArtifactError, "stale kernel or Ruby ABI mismatch: #{name}; rebuild"
      end
      library = File.join(dir, "#{feature}.#{RbConfig::CONFIG.fetch('DLEXT')}")
      actual = Digest::SHA256.file(library).hexdigest
      raise ArtifactError, 'extension checksum mismatch' unless actual == id && actual == metadata.fetch('extension_sha256')
      [library, metadata]
    rescue Errno::ENOENT, JSON::ParserError, KeyError => e
      raise ArtifactError, "#{name}: native artifact unavailable; run spinel-accel build (#{e.message})"
    end

    def native_method(entry)
      @mutex.synchronize do
        unless @native_module
          library, = artifact
          require library
          @native_module = Object.const_get(native_constant, false)
          entries.each_key do |key|
            raise ArtifactError, "#{key} is not a native method" if @native_module.method(key).source_location
          end
        end
        @native_module.method(entry.to_s)
      end
    rescue LoadError, NameError => e
      raise ArtifactError, "#{name}: failed to load native extension: #{e.message}"
    end

    def call(entry, *args, mode: ENV.fetch('SPINEL_ACCEL_MODE', 'ruby'))
      key = entry.to_s
      spec = entries.fetch(key) { raise ConfigurationError, "unknown entry: #{key}" }
      raise ContractError, "#{key} expects #{spec['params'].length} arguments" unless args.length == spec['params'].length
      spec['params'].zip(args).each_with_index { |(type, value), i| Contract.validate!(type, value, "#{key} argument #{i}") }
      case mode.to_s
      when 'ruby' then invoke(ruby_method(key), spec, args)
      when 'native' then invoke(native_method(key), spec, args)
      when 'verify' then verify(key, spec, args)
      else raise ConfigurationError, "unknown mode: #{mode}"
      end
    end

    def check!
      count = 0
      entries.each_key do |entry|
        cases = samples.fetch(entry, [])
        raise ConfigurationError, "no samples for #{name}.#{entry}" if cases.empty?
        cases.each { |args| call(entry, *args, mode: :verify); count += 1 }
      end
      count
    end

    private

    def invoke(method, spec, args)
      value = method.call(*args)
      Contract.validate!(spec.fetch('returns'), value, 'return value')
      value
    end

    def outcome(method, spec, args)
      begin
        value = invoke(method, spec, args)
        [:value, value]
      rescue StandardError => e
        [:error, e]
      end
    end

    def verify(key, spec, args)
      copies = [Contract.copy(args), Contract.copy(args)]
      expected = outcome(ruby_method(key), spec, copies[0])
      actual = outcome(native_method(key), spec, copies[1])
      raise MutationError, "#{name}.#{key} mutated its inputs" unless copies.all? { |copy| Contract.equal?(copy, args) }
      same = expected[0] == actual[0] && if expected[0] == :error
        expected[1].class == actual[1].class && expected[1].message == actual[1].message
      else
        Contract.equal?(expected[1], actual[1])
      end
      raise Mismatch, "#{name}.#{key}: Ruby and native results differ" unless same
      raise expected[1] if expected[0] == :error
      actual[1]
    end
  end
end

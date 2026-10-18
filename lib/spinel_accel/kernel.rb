# frozen_string_literal: true

require 'thread'

module SpinelAccel
  class Kernel
    MODES = %w[ruby native verify].freeze

    attr_reader :name, :source, :source_text, :module_name, :entries, :samples, :bench_inputs, :cache_dir, :fingerprint, :mode

    def initialize(name:, source:, module_name:, entries:, samples: {}, bench_inputs: {},
                   cache_dir: ENV.fetch('SPINEL_ACCEL_CACHE', '.spinel_accel'), mode: ENV.fetch('SPINEL_ACCEL_MODE', 'ruby'))
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
      @bench_inputs = bench_inputs.to_h.to_h do |key, cases|
        entry = key.to_s.dup.freeze
        spec = @entries.fetch(entry) { raise ConfigurationError, "bench_inputs for unknown entry: #{entry}" }
        cases.each do |args|
          unless args.length == spec['params'].length && spec['params'].zip(args).all? { |type, value| Contract.valid?(type, value) }
            raise ConfigurationError, "bench_inputs for #{entry} do not match its params"
          end
        end
        [entry, cases.map { |args| Contract.frozen_copy(args) }.freeze]
      end.freeze
      @mode = mode.to_s.dup.freeze
      raise ConfigurationError, "unknown mode: #{@mode}" unless MODES.include?(@mode)
      # Symbol and String keys both resolve without allocating on each call.
      @lookup = with_symbol_keys(@entries.to_h { |key, spec| [key, [key, spec].freeze] })
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
      resolve(@ruby_methods || load_ruby_methods, entry)
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
      resolve(@native_methods || load_native_methods, entry)
    end

    def call(entry, *args, mode: @mode)
      key, spec = @lookup[entry] || raise(ConfigurationError, "unknown entry: #{entry}")
      params = spec['params']
      raise ContractError, "#{key} expects #{params.length} arguments" unless args.length == params.length
      i = 0
      while i < params.length
        raise ContractError, "#{key} argument #{i} must be #{params[i]}" unless Contract.valid?(params[i], args[i])
        i += 1
      end
      case mode
      when 'ruby', :ruby then invoke(ruby_method(key), spec, args)
      when 'native', :native then invoke(native_method(key), spec, args)
      when 'verify', :verify then verify(key, spec, args)
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

    def with_symbol_keys(hash)
      hash.merge(hash.transform_keys(&:to_sym)).freeze
    end

    def resolve(methods, entry)
      methods.fetch(entry) { raise ConfigurationError, "unknown entry: #{entry}" }
    end

    # Method tables are built once and published frozen, so calls read them
    # without taking the lock.
    def load_ruby_methods
      @mutex.synchronize do
        @ruby_methods ||= begin
          scope = Module.new
          scope.module_eval(source_text, source, 1)
          mod = module_name.split('::').reduce(scope) { |parent, key| parent.const_get(key, false) }
          with_symbol_keys(entries.keys.to_h { |key| [key, mod.method(key)] })
        end
      end
    end

    def load_native_methods
      @mutex.synchronize do
        @native_methods ||= begin
          library, = artifact
          require library
          mod = Object.const_get(native_constant, false)
          methods = entries.keys.to_h { |key| [key, mod.method(key)] }
          methods.each do |key, method|
            raise ArtifactError, "#{key} is not a native method" if method.source_location
          end
          with_symbol_keys(methods)
        end
      end
    rescue LoadError, NameError => e
      raise ArtifactError, "#{name}: failed to load native extension: #{e.message}"
    end

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
      raise Mismatch, "#{name}.#{key}: Ruby and native results differ" unless same_outcome?(expected, actual)
      kind, payload = expected
      raise payload if kind == :error
      actual[1]
    end

    def same_outcome?(expected, actual)
      expected_kind, expected_payload = expected
      actual_kind, actual_payload = actual
      return false unless expected_kind == actual_kind
      return Contract.equal?(expected_payload, actual_payload) unless expected_kind == :error
      expected_payload.class == actual_payload.class && expected_payload.message == actual_payload.message
    end
  end
end

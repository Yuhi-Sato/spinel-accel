# frozen_string_literal: true

module SpinelAccel
  module Contract
    # The pinned CRuby shim accepts FIXNUMs, including inside integer arrays.
    INTEGER_RANGE = (-(1 << 62)..((1 << 62) - 1)).freeze
    STRING_ENCODINGS = [Encoding::UTF_8, Encoding::US_ASCII].freeze

    string = lambda do |value|
      value.instance_of?(String) && STRING_ENCODINGS.include?(value.encoding) && value.valid_encoding? && !value.include?("\0")
    end
    # Array checks run once per call on the hot path, so they lean on C-level
    # iteration instead of a Ruby block per element.
    VALIDATORS = {
      'integer' => ->(value) { value.is_a?(Integer) && INTEGER_RANGE.cover?(value) },
      'float' => ->(value) { value.is_a?(Float) && value.finite? },
      'boolean' => ->(value) { value.equal?(true) || value.equal?(false) },
      'string' => string,
      'integer_array' => lambda do |value|
        value.instance_of?(Array) && value.all?(Integer) &&
          (value.empty? || (INTEGER_RANGE.cover?(value.min) && INTEGER_RANGE.cover?(value.max)))
      end,
      # A non-finite element always makes the sum non-finite; only a finite
      # overflow needs the per-element fallback.
      'float_array' => ->(value) { value.instance_of?(Array) && value.all?(Float) && (value.sum.finite? || value.all?(&:finite?)) },
      'string_array' => ->(value) { value.instance_of?(Array) && value.all?(&string) }
    }.freeze
    TYPES = VALIDATORS.keys.freeze

    def self.validate_type!(type)
      raise ConfigurationError, "unsupported boundary type: #{type}" unless TYPES.include?(type.to_s)
      type.to_s.dup.freeze
    end

    def self.valid?(type, value)
      VALIDATORS.fetch(type.to_s).call(value)
    end

    def self.validate!(type, value, label)
      raise ContractError, "#{label} must be #{type}" unless valid?(type, value)
      true
    end

    def self.seed(type)
      { 'integer' => '0', 'float' => '0.0', 'boolean' => 'true', 'string' => '"seed"',
        'integer_array' => '[0]', 'float_array' => '[0.0]', 'string_array' => '["seed"]' }.fetch(type)
    end

    def self.copy(value)
      case value
      when Array then value.map { |v| copy(v) }
      when String then value.dup
      else value
      end
    end

    def self.equal?(a, b)
      return false unless a.class == b.class
      return [a].pack('G') == [b].pack('G') if a.is_a?(Float)
      return a.encoding == b.encoding && a == b if a.is_a?(String)
      return a.length == b.length && a.zip(b).all? { |x, y| equal?(x, y) } if a.is_a?(Array)
      a == b
    end

    def self.frozen_copy(value)
      return value.map { |item| frozen_copy(item) }.freeze if value.is_a?(Array)
      return value.dup.freeze if value.is_a?(String)
      value.freeze
    end
  end
end

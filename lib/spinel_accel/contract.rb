# frozen_string_literal: true

module SpinelAccel
  module Contract
    TYPES = %w[integer float boolean string integer_array float_array string_array].freeze
    # The pinned CRuby shim accepts FIXNUMs, including inside integer arrays.
    INTEGER_RANGE = (-(1 << 62)..((1 << 62) - 1)).freeze

    def self.validate_type!(type)
      raise ConfigurationError, "unsupported boundary type: #{type}" unless TYPES.include?(type.to_s)
      type.to_s.dup.freeze
    end

    def self.validate!(type, value, label)
      type = type.to_s
      valid = case type
              when 'integer' then value.is_a?(Integer) && INTEGER_RANGE.cover?(value)
              when 'float' then value.is_a?(Float) && value.finite?
              when 'boolean' then value.equal?(true) || value.equal?(false)
              when 'string'
                value.instance_of?(String) && [Encoding::UTF_8, Encoding::US_ASCII].include?(value.encoding) && value.valid_encoding? && !value.include?("\0")
              else
                type.end_with?('_array') && value.instance_of?(Array) && value.all? do |item|
                  validate!(type.delete_suffix('_array'), item, label)
                end
              end
      raise ContractError, "#{label} must be #{type}" unless valid
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

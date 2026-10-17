module ExampleArithmetic
  def self.sum(values)
    total = 0
    values.each { |value| total += value }
    total
  end

  def self.triple(value)
    value * 3
  end

  def self.halve(values)
    values.map { |value| value / 2.0 }
  end

  def self.shout(values)
    values.map { |value| value.upcase + '!' }
  end

  def self.negate(value)
    !value
  end

  def self.echo(value)
    value
  end

  def self.positive(value)
    raise ArgumentError, 'positive value required' if value <= 0
    value
  end

  def self.scale(value)
    value * 0.5
  end

  def self.shift(values)
    values.map { |value| value + 1 }
  end

  def self.constant
    7
  end
end

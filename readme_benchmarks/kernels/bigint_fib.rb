# Big-integer Fibonacci: fib(n) via repeated bignum addition.
# Returns the decimal string the original prints (the value exceeds 2**62).
# Note: the result is built via string interpolation so Ruby returns a UTF-8
# string (Integer#to_s/join yield US-ASCII, which verify mode treats as a
# mismatch against the native UTF-8 result).
module BigintFibKernel
  def self.run(n)
    a = 0
    b = 1
    i = 0
    while i < n
      c = a + b
      a = b
      b = c
      i = i + 1
    end
    "#{a}"
  end
end

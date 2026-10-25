module SieveKernel
  # Runs the sieve `num` times over `size` flags and returns the final count.
  def self.run(num, size)
    count = 0
    k = 0
    while k < num
      k = k + 1
      count = 0
      flags = Array.new(size, 1)
      i = 2
      while i < size
        i = i + 1
        if flags[i] == 1
          j = i * i
          while j < size
            j = j + i
            flags[j] = 0
          end
          count = count + 1
        end
      end
    end
    count
  end
end

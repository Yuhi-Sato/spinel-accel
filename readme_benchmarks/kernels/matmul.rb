module MatmulKernel
  def self.matgen(n)
    a = Array.new(n * n, 0.0)
    i = 0
    while i < n
      j = 0
      while j < n
        a[i * n + j] = (1.0 / n / n) * (i - j) * (i + j)
        j = j + 1
      end
      i = i + 1
    end
    a
  end

  def self.matmul(a, b, n)
    c = Array.new(n * n, 0.0)
    i = 0
    while i < n
      k = 0
      while k < n
        aik = a[i * n + k]
        j = 0
        while j < n
          c[i * n + j] = c[i * n + j] + aik * b[k * n + j]
          j = j + 1
        end
        k = k + 1
      end
      i = i + 1
    end
    c
  end

  # Returns the lines the original prints, joined with "\n".
  def self.run(n)
    a = matgen(n)
    b = matgen(n)
    c = matmul(a, b, n)
    "#{(c[0] * 1000000).to_i}\n#{(c[n * n - 1] * 1000000).to_i}\ndone"
  end
end

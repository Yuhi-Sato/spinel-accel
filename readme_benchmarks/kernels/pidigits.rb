# Port of Spinel benchmark/bm_pidigits.rb.
# Returns the digit string the original prints (without the trailing newline).
module PidigitsKernel
  def self.pidigits(n)
    q = 1
    r = 0
    t = 1
    k = 0
    i = 0
    result = ""
    while i < n
      k = k + 1
      b = 2 * k + 1
      nq = q * k
      nr = (2 * q + r) * b
      nt = t * b
      q = nq
      r = nr
      t = nt
      while (q * 3 + r) / t == (q * 4 + r) / t
        d = (q * 3 + r) / t
        result = result + d.to_s
        r = 10 * (r - d * t)
        q = q * 10
        i = i + 1
        if i >= n
          break
        end
      end
    end
    result
  end
end

module MandelTermKernel
  def self.mandelbrot(c_r, c_i)
    limit = 95
    iterations = 0
    cr = (c_r * 100).to_i
    ci = (c_i * 100).to_i
    zr = zi = 0
    # Avoid sqrt by squaring the threshold: sqrt(x) < 1000 => x < 1000000
    while iterations < limit
      zr2 = zr * zr
      zi2 = zi * zi
      break if zr2 + zi2 >= 1000000
      zr, zi = (zr2 - zi2) / 100 + cr, (zr * zi * 2) / 100 + ci
      iterations += 1
    end
    iterations
  end

  # Returns the text the original prints with putc.
  def self.mandel_calc(min_r, min_i, max_r, max_i, res)
    out = +""
    cur_i = min_i
    while cur_i > max_i
      out << "|"
      cur_r = min_r
      while cur_r < max_r
        ch = 127 - mandelbrot(cur_r, cur_i)
        out << ch.chr
        cur_r += res
      end
      out << "|"
      out << "\n"
      cur_i -= res
    end
    out
  end
end

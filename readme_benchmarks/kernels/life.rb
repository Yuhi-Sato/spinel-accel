# Deviation from original: the H/W/GENERATIONS constants became the h, w, generations
# parameters (threaded through cell_get/neighbors/next_gen); the initial pattern and
# rules are unchanged. Returns the live-cell count the original prints.
module LifeKernel
  OFFSETS = [-1, 0, 1]

  def self.cell_get(cells, x, y, h, w)
    cells[(y % h) * w + (x % w)]
  end

  def self.neighbors(cells, x, y, h, w)
    OFFSETS.sum { |iy|
      OFFSETS.count { |ix| cell_get(cells, x + ix, y + iy, h, w) == 1 }
    }
  end

  def self.next_gen(cells, h, w)
    Array.new(h * w) { |i|
      y = i / w
      x = i % w
      n = neighbors(cells, x, y, h, w)
      if n == 3
        1
      elsif n == 4 && cells[i] == 1
        1
      else
        0
      end
    }
  end

  def self.run(h, w, generations)
    cells = Array.new(h * w) { 0 }

    # Glider at (1,1)
    cells[1 * w + 2] = 1
    cells[2 * w + 3] = 1
    cells[3 * w + 1] = 1
    cells[3 * w + 2] = 1
    cells[3 * w + 3] = 1

    # Blinker at (10,10)
    cells[10 * w + 10] = 1
    cells[10 * w + 11] = 1
    cells[10 * w + 12] = 1

    gen = 0
    while gen < generations
      cells = next_gen(cells, h, w)
      gen = gen + 1
    end

    cells.count { _1 == 1 }
  end
end

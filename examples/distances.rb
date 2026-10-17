# frozen_string_literal: true

module DistanceKernel
  # Parallel arrays avoid object traversal at the native boundary.
  def self.distances(xs, ys, origin_x, origin_y)
    raise ArgumentError, 'coordinate lengths differ' unless xs.length == ys.length
    result = []
    i = 0
    while i < xs.length
      dx = xs[i] - origin_x
      dy = ys[i] - origin_y
      dx = -dx if dx < 0
      dy = -dy if dy < 0
      result << dx + dy
      i += 1
    end
    result
  end
end

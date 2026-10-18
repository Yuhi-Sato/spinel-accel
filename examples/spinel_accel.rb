# frozen_string_literal: true

require 'spinel_accel'

# Run from the project root:
#   spinel-accel build distances --config examples/spinel_accel.rb --spinel-root /path/to/spinel
#   spinel-accel check distances --config examples/spinel_accel.rb
#   spinel-accel bench distances --config examples/spinel_accel.rb
SpinelAccel.register :distances,
  source: File.expand_path('distances.rb', __dir__),
  module_name: 'DistanceKernel',
  entries: {
    distances: { params: [:integer_array, :integer_array, :integer, :integer], returns: :integer_array }
  },
  samples: {
    distances: [
      [[], [], 0, 0],
      [[0, -10, 7], [0, 20, -3], 2, -1],
      [Array.new(4096) { |i| (i * 37) % 2001 - 1000 },
       Array.new(4096) { |i| (i * 19) % 2001 - 1000 }, 100, -100]
    ]
  },
  bench_inputs: {
    distances: [
      [Array.new(4096) { |i| (i * 37) % 2001 - 1000 },
       Array.new(4096) { |i| (i * 19) % 2001 - 1000 }, 100, -100]
    ]
  }

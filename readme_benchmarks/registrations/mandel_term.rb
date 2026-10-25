# frozen_string_literal: true

SpinelAccel.register :mandel_term, source: File.expand_path('../kernels/mandel_term.rb', __dir__),
  module_name: 'MandelTermKernel',
  entries: { mandel_calc: { params: %i[float float float float float], returns: :string } },
  samples: { mandel_calc: [[-2.0, 1.0, 1.0, -1.0, 0.5], [0.0, 0.0, 0.0, 0.0, 0.1], [-1.0, 0.5, 0.5, -0.5, 0.25],
                           [-2.0, 1.0, 1.0, -1.0, 0.04]] },
  bench_inputs: { mandel_calc: [[-2.0, 1.0, 1.0, -1.0, 0.04]] }

# frozen_string_literal: true

SpinelAccel.register :pidigits, source: File.expand_path('../kernels/pidigits.rb', __dir__), module_name: 'PidigitsKernel',
  entries: { pidigits: { params: %i[integer], returns: :string } },
  samples: { pidigits: [[0], [1], [5], [27]] },
  bench_inputs: { pidigits: [[27]] }

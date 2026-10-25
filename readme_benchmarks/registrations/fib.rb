# frozen_string_literal: true

SpinelAccel.register :fib, source: File.expand_path('../kernels/fib.rb', __dir__), module_name: 'FibKernel',
  entries: { fib: { params: %i[integer], returns: :integer } },
  samples: { fib: [[0], [1], [20]] },
  bench_inputs: { fib: [[34]] }

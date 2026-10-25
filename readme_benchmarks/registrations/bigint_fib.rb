# frozen_string_literal: true

SpinelAccel.register :bigint_fib, source: File.expand_path('../kernels/bigint_fib.rb', __dir__), module_name: 'BigintFibKernel',
  entries: { run: { params: %i[integer], returns: :string } },
  samples: { run: [[0], [1], [90], [100], [1000]] },
  bench_inputs: { run: [[1000]] }

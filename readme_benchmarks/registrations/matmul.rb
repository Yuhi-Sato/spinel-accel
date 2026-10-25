# frozen_string_literal: true

SpinelAccel.register :matmul, source: File.expand_path('../kernels/matmul.rb', __dir__), module_name: 'MatmulKernel',
  entries: { run: { params: %i[integer], returns: :string } },
  samples: { run: [[1], [2], [10], [150]] },
  bench_inputs: { run: [[150]] }

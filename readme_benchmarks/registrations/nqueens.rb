# frozen_string_literal: true

SpinelAccel.register :nqueens, source: File.expand_path('../kernels/nqueens.rb', __dir__), module_name: 'NqueensKernel',
  entries: { run: { params: %i[integer integer], returns: :integer } },
  samples: { run: [[1, 1], [4, 2], [8, 1], [10, 10]] },
  bench_inputs: { run: [[10, 10]] }

# frozen_string_literal: true

SpinelAccel.register :rbtree, source: File.expand_path('../kernels/rbtree.rb', __dir__), module_name: 'RbtreeKernel',
  entries: { run: { params: %i[integer integer], returns: :string } },
  samples: { run: [[1, 1], [100, 3], [10000, 10]] },
  bench_inputs: { run: [[10000, 10]] }

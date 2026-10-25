# frozen_string_literal: true

SpinelAccel.register :binary_trees, source: File.expand_path('../kernels/binary_trees.rb', __dir__), module_name: 'BinaryTreesKernel',
  entries: { run: { params: %i[integer], returns: :string } },
  samples: { run: [[0], [6], [7], [10]] },
  bench_inputs: { run: [[10]] }

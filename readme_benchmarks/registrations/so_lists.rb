# frozen_string_literal: true

SpinelAccel.register :so_lists, source: File.expand_path('../kernels/so_lists.rb', __dir__), module_name: 'SoListsKernel',
  entries: { so_lists: { params: %i[integer integer], returns: :integer } },
  samples: { so_lists: [[1, 1], [3, 10], [2, 1000], [300, 10_000]] },
  bench_inputs: { so_lists: [[300, 10_000]] }

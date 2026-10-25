# frozen_string_literal: true

SpinelAccel.register :linked_list, source: File.expand_path('../kernels/linked_list.rb', __dir__), module_name: 'LinkedListKernel',
  entries: { linked_list: { params: %i[integer integer], returns: :string } },
  samples: { linked_list: [[1, 1], [10, 2], [1000, 3], [100_000, 10]] },
  bench_inputs: { linked_list: [[100_000, 10]] }

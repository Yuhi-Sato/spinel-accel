# frozen_string_literal: true

SpinelAccel.register :splay, source: File.expand_path('../kernels/splay.rb', __dir__), module_name: 'SplayKernel',
  entries: { run: { params: %i[integer], returns: :string } },
  samples: { run: [[0], [1], [1000], [25000]] },
  bench_inputs: { run: [[25000]] }

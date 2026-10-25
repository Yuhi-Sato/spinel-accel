# frozen_string_literal: true

SpinelAccel.register :tak, source: File.expand_path('../kernels/tak.rb', __dir__), module_name: 'TakKernel',
  entries: { tak: { params: %i[integer integer integer], returns: :integer } },
  samples: { tak: [[6, 3, 0], [0, 0, 0]] },
  bench_inputs: { tak: [[18, 9, 0]] }

# frozen_string_literal: true

SpinelAccel.register :gcbench, source: File.expand_path('../kernels/gcbench.rb', __dir__), module_name: 'GcbenchKernel',
  entries: { run: { params: %i[integer integer integer integer], returns: :string } },
  samples: { run: [[4, 2, 4, 4], [8, 6, 4, 8], [18, 16, 4, 16]] },
  bench_inputs: { run: [[18, 16, 4, 16]] }

# frozen_string_literal: true

SpinelAccel.register :life, source: File.expand_path('../kernels/life.rb', __dir__), module_name: 'LifeKernel',
  entries: { run: { params: %i[integer integer integer], returns: :integer } },
  samples: { run: [[40, 80, 0], [40, 80, 1], [20, 20, 7], [40, 80, 200]] },
  bench_inputs: { run: [[40, 80, 200]] }

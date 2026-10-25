# frozen_string_literal: true

SpinelAccel.register :tarai, source: File.expand_path('../kernels/tarai.rb', __dir__), module_name: 'TaraiKernel',
  entries: { tarai: { params: %i[integer integer integer], returns: :integer } },
  samples: { tarai: [[0, 0, 0], [6, 3, 0], [12, 6, 0]] },
  bench_inputs: { tarai: [[12, 6, 0]] }

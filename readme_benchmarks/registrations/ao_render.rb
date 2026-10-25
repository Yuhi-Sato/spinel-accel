# frozen_string_literal: true

SpinelAccel.register :ao_render, source: File.expand_path('../kernels/ao_render.rb', __dir__), module_name: 'AoRenderKernel',
  entries: { render: { params: %i[integer], returns: :integer_array } },
  samples: { render: [[0], [1], [8], [64]] },
  bench_inputs: { render: [[64]] }

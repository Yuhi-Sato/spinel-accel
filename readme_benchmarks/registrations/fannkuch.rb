# frozen_string_literal: true

SpinelAccel.register :fannkuch, source: File.expand_path('../kernels/fannkuch.rb', __dir__), module_name: 'FannkuchKernel',
  entries: { fannkuch: { params: %i[integer], returns: :string } },
  samples: { fannkuch: [[3], [4], [5], [7]] },
  bench_inputs: { fannkuch: [[7]] }

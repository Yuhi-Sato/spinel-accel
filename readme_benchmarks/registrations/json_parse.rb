# frozen_string_literal: true

SpinelAccel.register :json_parse, source: File.expand_path('../kernels/json_parse.rb', __dir__), module_name: 'JsonParseKernel',
  entries: { run: { params: %i[integer], returns: :string } },
  samples: { run: [[0], [1], [100]] },
  bench_inputs: { run: [[10_000]] }

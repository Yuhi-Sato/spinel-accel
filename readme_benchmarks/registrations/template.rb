# frozen_string_literal: true

SpinelAccel.register :template, source: File.expand_path('../kernels/template.rb', __dir__), module_name: 'TemplateKernel',
  entries: { run: { params: %i[integer], returns: :string } },
  samples: { run: [[0], [1], [100]] },
  bench_inputs: { run: [[50_000]] }

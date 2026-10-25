# frozen_string_literal: true

SpinelAccel.register :str_concat, source: File.expand_path('../kernels/str_concat.rb', __dir__), module_name: 'StrConcatKernel',
  entries: { run: { params: %i[integer string], returns: :integer } },
  samples: { run: [[0, "ssssssee"], [1, ""], [3, "ab"], [10240, "ssssssee"]] },
  bench_inputs: { run: [[10240, "ssssssee"]] }

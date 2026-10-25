# frozen_string_literal: true

SpinelAccel.register :io_wordcount, source: File.expand_path('../kernels/io_wordcount.rb', __dir__), module_name: 'IoWordcountKernel',
  entries: { run: { params: %i[integer integer], returns: :string } },
  samples: { run: [[0, 0], [3, 1], [100, 2], [5000, 20]] },
  bench_inputs: { run: [[5000, 20]] }

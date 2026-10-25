# frozen_string_literal: true

SpinelAccel.register :csv_process, source: File.expand_path('../kernels/csv_process.rb', __dir__), module_name: 'CsvProcessKernel',
  entries: { run: { params: %i[integer integer], returns: :string } },
  samples: { run: [[0, 0], [1, 1], [100, 3], [5000, 200]] },
  bench_inputs: { run: [[5000, 200]] }

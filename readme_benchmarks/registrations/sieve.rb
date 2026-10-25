# frozen_string_literal: true

SpinelAccel.register :sieve, source: File.expand_path('../kernels/sieve.rb', __dir__), module_name: 'SieveKernel',
  entries: { run: { params: %i[integer integer], returns: :integer } },
  samples: { run: [[1, 100], [3, 1000], [0, 8192], [500, 8192]] },
  bench_inputs: { run: [[500, 8192]] }

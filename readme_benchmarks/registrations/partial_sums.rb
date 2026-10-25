# frozen_string_literal: true

SpinelAccel.register :partial_sums, source: File.expand_path('../kernels/partial_sums.rb', __dir__),
  module_name: 'PartialSumsKernel',
  entries: { run: { params: %i[integer], returns: :string } },
  samples: { run: [[0], [1], [1000], [2500000]] },
  bench_inputs: { run: [[2500000]] }

# frozen_string_literal: true

SpinelAccel.register :ackermann, source: File.expand_path('../kernels/ackermann.rb', __dir__), module_name: 'AckermannKernel',
  entries: { ack: { params: %i[integer integer], returns: :integer } },
  samples: { ack: [[0, 0], [1, 2], [2, 3], [3, 9]] },
  bench_inputs: { ack: [[3, 9]] }

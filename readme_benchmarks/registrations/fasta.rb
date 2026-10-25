# frozen_string_literal: true

SpinelAccel.register :fasta, source: File.expand_path('../kernels/fasta.rb', __dir__), module_name: 'FastaKernel',
  entries: { fasta: { params: %i[integer], returns: :string } },
  samples: { fasta: [[0], [1], [31], [1000]] },
  bench_inputs: { fasta: [[1000]] }

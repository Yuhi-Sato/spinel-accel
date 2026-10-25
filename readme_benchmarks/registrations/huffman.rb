# frozen_string_literal: true

SpinelAccel.register :huffman, source: File.expand_path('../kernels/huffman.rb', __dir__), module_name: 'HuffmanKernel',
  entries: { huffman: { params: %i[integer], returns: :string } },
  samples: { huffman: [[1], [2], [100], [200_000]] },
  bench_inputs: { huffman: [[200_000]] }

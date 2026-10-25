# frozen_string_literal: true

sudoku_puzzle = [46, 46, 46, 46, 46, 46, 46, 46, 46, 46, 46, 46, 46, 46, 51, 46, 56, 53, 46, 46, 49, 46, 50, 46, 46, 46,
                 46, 46, 46, 46, 53, 46, 55, 46, 46, 46, 46, 46, 52, 46, 46, 46, 49, 46, 46, 46, 57, 46, 46, 46, 46, 46,
                 46, 46, 53, 46, 46, 46, 46, 46, 46, 55, 51, 46, 46, 50, 46, 49, 46, 46, 46, 46, 46, 46, 46, 46, 52, 46,
                 46, 46, 57]
# A puzzle with many hints (one solution) and an invalid one (duplicate 1s in row 0, no solution).
sudoku_easy = '53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79'.bytes
sudoku_bad = ([49, 49] + Array.new(79, 46))

SpinelAccel.register :sudoku, source: File.expand_path('../kernels/sudoku.rb', __dir__), module_name: 'SudokuKernel',
  entries: { run: { params: %i[integer_array integer], returns: :integer } },
  samples: { run: [[sudoku_easy, 1], [sudoku_bad, 1], [sudoku_puzzle, 1], [sudoku_puzzle, 100]] },
  bench_inputs: { run: [[sudoku_puzzle, 100]] }

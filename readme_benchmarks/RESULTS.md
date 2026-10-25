# Spinel README benchmarks through spinel-accel

The 28 benchmarks from Spinel's README (pinned 72e45de), ported to spinel-accel kernels and timed in-process with `spinel-accel bench`.

- Ruby 4.0.3 (arm64-darwin25), built with `--enable-yjit`; macOS arm64, Apple clang
- `RUBYOPT=--yjit spinel-accel bench --target-ms 300` → `results-yjit.json`; same without YJIT → `results-interp.json`
- Bench inputs reproduce each original script's problem size; every kernel passes `check`, and Ruby-mode output matches the original `.expected`
- Timings include argument validation and Ruby/native conversion (per call, not per process); README numbers are whole-process wall time on Linux/gcc against Ruby 4.0.4

| Benchmark | Native | Ruby | Ruby + YJIT | vs YJIT | vs Ruby | README vs YJIT |
|---|---|---|---|---|---|---|
| mandelbrot (mandel_term) | 511 µs | 5.2 ms | 1.1 ms | 2.2x | 10.1x | 53.6x |
| fib | 13.5 ms | 264.2 ms | 45.0 ms | 3.3x | 18.5x | 44.6x |
| matmul | 2.9 ms | 129.2 ms | 49.2 ms | 17.1x | 44.9x | 32.9x |
| nqueens | 2.4 ms | 93.9 ms | 25.6 ms | 10.7x | 38.2x | 23.6x |
| sieve | 6.5 ms | 170.4 ms | 57.7 ms | 8.8x | 23.0x | 19.2x |
| partial_sums | 8.8 ms | 525.7 ms | 256.0 ms | 29.1x | 56.4x | 19.0x |
| life | 15.6 ms | 365.0 ms | 175.7 ms | 11.3x | 23.6x | 12.1x |
| sudoku | 1.0 ms | 47.9 ms | 11.7 ms | 11.4x | 45.7x | 9.6x |
| fannkuch | 61 µs | 1.8 ms | 678 µs | 11.2x | 29.9x | 6.8x |
| fasta | 210 µs | 1.4 ms | 657 µs | 3.1x | 6.7x | 5.9x |
| tak | 8.3 ms | 237.3 ms | 42.4 ms | 5.1x | 28.7x | 5.9x |
| ackermann | 26.9 ms | 213.8 ms | 29.9 ms | 1.1x | 8.2x | 5.8x |
| tarai | 6.9 ms | 184.6 ms | 33.2 ms | 4.8x | 27.0x | 5.5x |
| so_lists | 11.9 ms | 161.6 ms | 80.9 ms | 6.8x | 13.5x | 13.1x |
| huffman | 2.9 ms | 19.7 ms | 9.8 ms | 3.3x | 6.5x | 7.2x |
| linked_list | 15.6 ms | 115.2 ms | 63.6 ms | 4.1x | 7.0x | 6.7x |
| gcbench | 125.1 ms | 1303.1 ms | 573.9 ms | 4.6x | 10.4x | 4.9x |
| binary_trees | 1.6 ms | 10.3 ms | 3.3 ms | 2.1x | 6.5x | 4.7x |
| rbtree | 12.4 ms | 191.7 ms | 48.6 ms | 3.9x | 15.2x | 4.5x |
| splay | 5.5 ms | 63.7 ms | 17.5 ms | 3.2x | 11.6x | 4.5x |
| ao_render | 47.2 ms | 1093.8 ms | 464.5 ms | 9.8x | 23.1x | 8.7x |
| bigint_fib | 31 µs | 38 µs | 34 µs | 1.1x | 1.1x | 6.8x |
| pidigits | 93 µs | 60 µs | 43 µs | 0.5x | 0.6x | 6.2x |
| template | 44.7 ms | 326.0 ms | 234.3 ms | 5.2x | 7.1x | 5.9x |
| json_parse | 20.0 ms | 133.3 ms | 84.0 ms | 4.2x | 6.1x | 4.7x |
| str_concat | 38 µs | 137 µs | 75 µs | 2.0x | 3.0x | 4.6x |
| csv_process | 86.1 ms | 292.6 ms | 236.5 ms | 2.7x | 3.2x | 4.2x |
| io_wordcount | 8.5 ms | 24.5 ms | 20.7 ms | 2.4x | 2.8x | 3.1x |
| **Geometric mean** | | | | **4.3x** | **10.8x** | 8.5x |

## Notes

- **mandelbrot**: the pinned tree has only `bm_mandel_term.rb`, a ~1 ms workload; README's 938 ms row comes from a different benchmark.
- **fib**: README's 44.6x comes from the C compiler folding `fib(34)` with a literal argument. A runtime argument gives 3.3x.
- **ackermann**: a standalone Spinel binary also takes 27 ms here, so the low ratio is Spinel on macOS/clang, not the extension boundary.
- **bigint_fib / pidigits**: microsecond-scale calls dominated by bignum work and boundary cost; native loses on pidigits.
- **io_wordcount**: kernels cannot do I/O, so the file is built and read as an in-memory String.
- Other deviations (globals → parameters, string encoding tweaks for verify mode) are documented at the top of each `kernels/*.rb`.

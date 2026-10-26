# Changelog

## Unreleased

- Pin Spinel to edge (`e1d92f1e1923664db9deb5b9e1dc5e3b309d2cfb`, master as of October 18, 2026).
- Validate arrays with C-level iteration; a 100,000-element integer array check drops from about 12 ms to 1 ms.
- Resolve Ruby and native methods once per kernel and call them without a lock; per-call overhead drops from about 0.77 to 0.41 microseconds.
- Read the default mode once at registration, accept `mode:` in `register`, and reject unknown modes early.
- Add `bench_inputs` so benchmarks can use representative inputs instead of correctness samples.

## 0.1.0

Initial release with explicit Ruby, native and verification modes; pinned Spinel builds; portable C bundles; ABI and checksum validation; environment diagnostics; and boundary-inclusive benchmarks.

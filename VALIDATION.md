# Validation

Validated on October 18, 2026 with Spinel revision `72e45de6e5411b98e8efbdf468e6660495026dc5`.

| Environment | Tests | Assertions | Failures / errors / skips |
| --- | ---: | ---: | --- |
| macOS arm64, CRuby 4.0.2 | 19 | 176 | 0 / 0 / 0 |
| Linux arm64, CRuby 3.3.6 in Docker | 19 | 176 | 0 / 0 / 0 |

Both runs used actual CRuby extensions. The Linux run compiled portable C bundles emitted on macOS, without a Spinel executable inside the container. Tests include integer/float/string/boolean inputs, arrays, namespaced modules, multiple extensions, randomized cases, exceptions, mutation detection, signed-zero comparisons, GC, threads, ABI rejection, and CLI failure paths.

An ISUCON14 application using the gem passed 57 tests and 845 assertions in each of native and Ruby modes on Linux / Ruby 3.3.6, including MySQL-backed dispatcher tests. Registry timeouts prevented a fresh application dependency download; the integration image reused previously installed dependencies and compiled the new extension from C. The standalone gem image resolved and installed its own development dependencies.

The built `.gem` was installed into an isolated gem directory. From a separate consumer directory, the installed executable successfully initialized, built, checked, and benchmarked the demo. The batched Manhattan-distance example also built and passed all three comparison samples.

The installed demo's seven-round benchmark, including validation and conversion, measured 1.074 microseconds per Ruby call and 1.232 microseconds per native call (0.872x). The example distance workload's mixed empty, three-element, and 4,096-element inputs measured 570.611 versus 538.403 microseconds (1.060x). These are macOS / Ruby 4.0.2 interpreter results; this Ruby build has no YJIT. They illustrate overhead and are not general speedup claims.

No x86_64 measurements, official ISUCON benchmark, deployment, or long-duration load test has been performed. Re-run correctness and performance checks on the target Ruby and representative application inputs before enabling native mode.

For reproducible commands, see the README's Development section. Native test skips must remain visible when the compiler and emitted test bundles are unavailable.

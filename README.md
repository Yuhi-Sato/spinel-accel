# spinel_accel

Compile selected Ruby computation kernels into CRuby extensions with [Spinel](https://github.com/matz/spinel), while keeping the rest of your application in Ruby. Register a pure function, build it explicitly, compare its behavior against Ruby, and measure the cost including data conversion.

The compiler is pinned to `72e45de6e5411b98e8efbdf468e6660495026dc5`. Native execution requires 64-bit CRuby. This project targets small, self-contained computations; Spinel does not support arbitrary Ruby applications.

## Installation

```ruby
# Gemfile
gem 'spinel_accel', git: 'git@github.com:Yuhi-Sato/spinel-accel.git', tag: 'v0.1.0'
```

Or build a local package:

```sh
gem build spinel_accel.gemspec
gem install ./spinel_accel-0.1.0.gem --local
```

The gem is not published to RubyGems.org. Installing it does not install Spinel. Ruby mode needs no compiler; native builds need the pinned Spinel source tree, Ruby development headers, make, and a C compiler.

## Quick start

```sh
spinel-accel init demo
cd demo
spinel-accel doctor --spinel-root /path/to/spinel
spinel-accel build demo --spinel-root /path/to/spinel
spinel-accel check demo
spinel-accel bench demo
```

`init` creates `kernel.rb` and `spinel_accel.rb`. It refuses to overwrite an existing directory. A registration looks like this:

```ruby
require 'spinel_accel'

SUM = SpinelAccel.register :sum,
  source: File.expand_path('kernel.rb', __dir__),
  module_name: 'SumKernel',
  entries: { sum: { params: [:integer_array], returns: :integer } },
  samples: { sum: [ [[1, 2, 3]], [[]], [[-2, 0, 2]] ] }
```

The source contains a self-contained module. The gem generates the type-inference driver; you do not need to add driver calls to your source. Namespaced modules and multiple entry methods are supported.

```ruby
module SumKernel
  def self.sum(values)
    total = 0
    values.each { |value| total += value }
    total
  end
end
```

Call the registered kernel from your application:

```ruby
SUM.call(:sum, [1, 2, 3], mode: :ruby)    # Execute the reference Ruby implementation
SUM.call(:sum, [1, 2, 3], mode: :native)  # Execute the prebuilt extension
SUM.call(:sum, [1, 2, 3], mode: :verify)  # Execute both and compare
```

The default is `ruby`. Set `SPINEL_ACCEL_MODE=ruby|native|verify` or pass `mode:` to `register` to change it. The default is read once when the kernel is registered, and an unknown value fails registration. Native and verify modes fail on missing artifacts, ABI mismatches, or checksum mismatches. They never silently fall back. Ruby code is evaluated in an anonymous scope, and each extension has a distinct module, so loading an extension does not replace the reference methods.

Tested with real native extensions on Linux arm64 / Ruby 3.3.6 and macOS arm64 / Ruby 4.0.2. See [VALIDATION.md](VALIDATION.md) for results and limitations.

See [examples/spinel_accel.rb](examples/spinel_accel.rb) for a batched Manhattan-distance workload.

## Function contracts

Use stateless, deterministic functions with fixed positional arguments. Avoid input mutation, database writes, external requests, clock reads, and randomness. Verify mode executes the function twice. It compares return types and values, signed floating-point zero, string encodings, and exception classes and messages. It copies inputs and raises `MutationError` if either implementation changes them.

| Declaration | Accepted values |
| --- | --- |
| `integer` | Integer from `-(2**62)` through `2**62 - 1` |
| `float` | Finite Float |
| `boolean` | `true` or `false` |
| `string` | Valid UTF-8 or US-ASCII String without NUL bytes |
| `integer_array` | Flat Array of the integers above |
| `float_array` | Flat Array of the floats above |
| `string_array` | Flat Array of the strings above |

Array and String subclasses are rejected. Hashes, keyword arguments, blocks, arbitrary objects, shared state, and external source dependencies are outside the contract. Both execution paths validate arguments and return values. The native boundary copies values.

Spinel compatibility still needs verification within these types. Test realistic inputs and edge cases, especially intermediate integer overflow and string operations. Different string encodings are treated as a mismatch. If both implementations raise the same exception, verify mode re-raises the reference exception. Samples used by `check` must return successfully.

## Building and distribution

Generate a portable C bundle on a machine with Spinel, then compile it for the target Ruby:

```sh
spinel-accel emit sum --config spinel_accel.rb --spinel-root /path/to/spinel
# Copy the reported bundle directory, registration, and original Ruby source to the target.
spinel-accel compile sum --config spinel_accel.rb --bundle /path/to/bundle
spinel-accel check sum
```

The bundle includes generated C, the Spinel runtime, its MIT license, and a checksum manifest. `compile` needs no Spinel executable. Build the extension on the target platform; a macOS `.bundle` cannot be used on Linux.

Artifacts default to `.spinel_accel/` in the working directory. Override this with `--cache-dir DIR` or `SPINEL_ACCEL_CACHE`. Source bytes, type contracts, the compiler revision, and the gem version identify each kernel. Native artifacts are separated by Ruby version, patchlevel, and architecture. Builds use a process lock and atomically publish a pointer to an immutable binary. Restart processes that have already loaded an older extension.

Build logs are saved as `build.log` under the kernel's cache. External commands use argument vectors and terminate their process group on timeout. Checksums detect changed or mismatched files; they are not publisher signatures. Load source, registration files, and C bundles from trusted authors.

To prepare the pinned compiler from an archive:

```sh
mkdir -p tmp/spinel-src
curl -fL https://api.github.com/repos/matz/spinel/tarball/72e45de6e5411b98e8efbdf468e6660495026dc5 -o tmp/spinel.tar.gz
tar -xzf tmp/spinel.tar.gz -C tmp/spinel-src --strip-components=1
ruby -e 'File.write("tmp/spinel-src/.spinel-dist", "72e45de6e5411b98e8efbdf468e6660495026dc5\nunreleased\n")'
GIT_CEILING_DIRECTORIES="$PWD/tmp" make -C tmp/spinel-src deps
GIT_CEILING_DIRECTORIES="$PWD/tmp" make -C tmp/spinel-src -j8
export SPINEL_ROOT="$PWD/tmp/spinel-src"
```

## Benchmarking and ISUCON preparation

`bench` first verifies every sample. Correctness samples are often tiny edge cases, so register representative timing inputs separately with `bench_inputs: { entry: [args, ...] }`. They must match the entry's params, are verified before timing, and replace that entry's samples as the workload; each JSON row reports its `workload`. Timings include argument validation, Ruby/native conversion, computation, and return validation. Defaults are 50 warmup calls and seven alternating Ruby/native rounds. JSON contains all timing samples and medians. Each mode processes the same fixture proportions.

```sh
RUBYOPT=--yjit spinel-accel bench sum --rounds 7 --warmup 50 --target-ms 30
```

Before an ISUCON event, prepare the pinned toolchain, generate portable bundles, and rehearse target-platform compilation and Ruby rollback. During optimization, profile the application first. Extract a CPU-heavy loop that can process a batch per call, add correctness samples, and measure both modes. Small functions can become slower because validation and conversion cost more than the calculation. Keep SQL, HTTP handlers, and transaction logic in the application.

Kernel benchmarks exclude database and HTTP costs. Run a representative application workload before drawing conclusions about throughput or scores. Native execution does not guarantee additional thread parallelism: this pinned compiler's generated shim serializes calls within each extension.

## Development

```sh
bundle install
SPINEL_ROOT=/path/to/spinel bundle exec rake test
```

Without `SPINEL_ROOT` or `SPINEL_ACCEL_TEST_BUNDLES`, native tests explicitly skip. A run with skips does not establish native correctness. Tests cover multiple entry methods, type boundaries, namespaces, coexistence of extensions, exceptions, input preservation, GC and threads, ABI checks, and the CLI.

To validate portable C compilation on Linux with Ruby 3.3.6:

```sh
SPINEL_ROOT=/path/to/spinel bundle exec ruby test/emit_bundles.rb
docker build -f test/Dockerfile -t spinel-accel-tests .
docker run --rm spinel-accel-tests
```

## License

MIT. Portable bundles retain the upstream Spinel runtime license.

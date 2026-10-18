# spinel_accel

Accelerate CPU-heavy parts of a Ruby application by compiling them into CRuby extensions with [Spinel](https://github.com/matz/spinel), while the rest of the application stays in Ruby. You register a pure function, build it explicitly, verify it against the Ruby implementation, and measure the speedup including data conversion.

- Spinel is pinned to `e1d92f1e1923664db9deb5b9e1dc5e3b309d2cfb`.
- Native execution requires 64-bit CRuby.
- Spinel compiles small, self-contained computations, not arbitrary Ruby applications.
- Tested on Linux arm64 / Ruby 3.3.6 and macOS arm64 / Ruby 4.0.2. See [VALIDATION.md](VALIDATION.md).

## Concepts

| Term | Meaning |
| --- | --- |
| **Kernel** | A small, pure, CPU-heavy Ruby module extracted from your application, compiled as one unit. The term comes from *compute kernels* in numerical computing and is unrelated to Ruby's built-in `Kernel` module. |
| **Entry** | A module method of a kernel that the application calls. A kernel can have several entries. |
| **Mode** | How a call executes: `ruby` (the reference implementation), `native` (the compiled extension), or `verify` (both, compared). |
| **Bundle** | Portable generated C code that a machine without Spinel can compile. |

## Installation

The gem is not published to RubyGems.org. Install it from Git:

```ruby
# Gemfile
gem 'spinel_accel', git: 'git@github.com:Yuhi-Sato/spinel-accel.git', tag: 'v0.1.0'
```

Ruby mode needs nothing else. Native builds need Ruby development headers, make, a C compiler, and the [pinned Spinel source tree](#preparing-spinel); compiling a bundle does not need Spinel.

## Quick start

```sh
spinel-accel init demo                              # Create a sample kernel and registration
cd demo
spinel-accel doctor --spinel-root /path/to/spinel  # Check the toolchain
spinel-accel build demo --spinel-root /path/to/spinel
spinel-accel check demo                             # Verify every sample against Ruby
spinel-accel bench demo                             # Compare Ruby and native timings
```

Set `SPINEL_ROOT` to omit `--spinel-root`.

## Usage

### 1. Write a kernel

The source file defines one self-contained module. Namespaced modules and multiple entries are supported.

```ruby
# kernel.rb
module SumKernel
  def self.sum(values)
    total = 0
    values.each { |value| total += value }
    total
  end
end
```

### 2. Register it

```ruby
# spinel_accel.rb
require 'spinel_accel'

SUM = SpinelAccel.register :sum,
  source: File.expand_path('kernel.rb', __dir__),
  module_name: 'SumKernel',
  entries: { sum: { params: [:integer_array], returns: :integer } },
  samples: { sum: [ [[1, 2, 3]], [[]], [[-2, 0, 2]] ] },
  bench_inputs: { sum: [ [Array.new(4096) { |i| i }] ] }
```

Each entry declares its parameter and return types from the [type contract](#type-contract). `samples` are correctness inputs; `bench_inputs` are representative timing inputs. Both map each entry to a list of argument lists.

### 3. Call it

```ruby
SUM.call(:sum, [1, 2, 3], mode: :ruby)    # Run the reference Ruby implementation
SUM.call(:sum, [1, 2, 3], mode: :native)  # Run the prebuilt extension
SUM.call(:sum, [1, 2, 3], mode: :verify)  # Run both and compare
```

The default mode is `ruby`. Change it with `SPINEL_ACCEL_MODE` or with `mode:` on `register`. `native` and `verify` raise on missing or mismatched artifacts and never silently fall back to Ruby.

See [examples/spinel_accel.rb](examples/spinel_accel.rb) for a batched Manhattan-distance workload.

## Function contract

A kernel entry must be stateless and deterministic, and take fixed positional arguments. It must not mutate its inputs, perform I/O, read the clock, or use randomness.

### Type contract

| Declaration | Accepted values |
| --- | --- |
| `integer` | Integer from `-(2**62)` through `2**62 - 1` |
| `float` | Finite Float |
| `boolean` | `true` or `false` |
| `string` | Valid UTF-8 or US-ASCII String without NUL bytes |
| `integer_array` | Flat Array of the integers above |
| `float_array` | Flat Array of the floats above |
| `string_array` | Flat Array of the strings above |

Array and String subclasses, Hashes, keyword arguments, blocks, and other objects are not supported.

### Verify mode

Verify mode runs both implementations and compares their return values (including type, signed zero, and string encoding) or raised exceptions (class and message). It raises `MutationError` if either implementation changes its inputs.

Staying within the declared types does not guarantee that Spinel matches Ruby. Test realistic edge cases, especially intermediate integer overflow and string operations.

## Commands

Kernel commands read registrations from `--config FILE` (default `spinel_accel.rb`) and run for every registered kernel when `NAME` is omitted. Results are printed as JSON.

| Command | Purpose |
| --- | --- |
| `init DIR` | Create a sample project in a new directory |
| `doctor` | Check the toolchain and the pinned Spinel compiler |
| `build [NAME]` | Compile kernels with Spinel into native extensions |
| `emit [NAME]` | Generate a portable C bundle |
| `compile NAME --bundle DIR` | Compile a bundle without Spinel |
| `check [NAME]` | Verify every sample in verify mode |
| `bench [NAME]` | Benchmark Ruby against native |

Run `spinel-accel --help` for all options.

## Building and distribution

### Portable bundles

To deploy to a machine without Spinel, generate a bundle where Spinel is available and compile it on the target:

```sh
spinel-accel emit sum --spinel-root /path/to/spinel
# Copy the reported bundle directory, the registration, and the Ruby source to the target.
spinel-accel compile sum --bundle /path/to/bundle
spinel-accel check sum
```

Build on the target platform; for example, a macOS `.bundle` cannot be loaded on Linux.

### Cache

Built extensions and `build.log` are stored in `.spinel_accel/` by default. Override it with `--cache-dir DIR` or `SPINEL_ACCEL_CACHE`. Changing the source, types, compiler, gem version, or Ruby version produces a separate build. Restart processes that already loaded an older extension.

Checksums detect changed files but are not signatures. Load sources, registrations, and bundles only from trusted authors.

### Preparing Spinel

```sh
mkdir -p tmp/spinel-src
curl -fL https://api.github.com/repos/matz/spinel/tarball/e1d92f1e1923664db9deb5b9e1dc5e3b309d2cfb -o tmp/spinel.tar.gz
tar -xzf tmp/spinel.tar.gz -C tmp/spinel-src --strip-components=1
ruby -e 'File.write("tmp/spinel-src/.spinel-dist", "e1d92f1e1923664db9deb5b9e1dc5e3b309d2cfb\nunreleased\n")'
GIT_CEILING_DIRECTORIES="$PWD/tmp" make -C tmp/spinel-src deps
GIT_CEILING_DIRECTORIES="$PWD/tmp" make -C tmp/spinel-src -j8
export SPINEL_ROOT="$PWD/tmp/spinel-src"
```

## Benchmarking

```sh
RUBYOPT=--yjit spinel-accel bench sum
```

`bench` verifies every sample, then times each entry on its `bench_inputs` (or its samples if none are registered). Timings include argument validation and Ruby/native conversion, not just the computation, so small functions can get slower. Calls within one extension are serialized, so native execution does not add thread parallelism.

Kernel benchmarks exclude database and HTTP costs. Measure a representative application workload before drawing conclusions about throughput.

## Using it in ISUCON

Before the event, prepare the pinned toolchain, generate bundles, and rehearse compiling on the target and rolling back to Ruby mode.

During the event, profile first, then extract a CPU-heavy loop that processes a batch per call. Keep SQL, HTTP handlers, and transaction logic in the application.

## Development

```sh
bundle install
SPINEL_ROOT=/path/to/spinel bundle exec rake test
```

Native tests are skipped unless `SPINEL_ROOT` or `SPINEL_ACCEL_TEST_BUNDLES` is set.

To validate portable C compilation on Linux with Ruby 3.3.6:

```sh
SPINEL_ROOT=/path/to/spinel bundle exec ruby test/emit_bundles.rb
docker build -f test/Dockerfile -t spinel-accel-tests .
docker run --rm spinel-accel-tests
```

## License

MIT. Portable bundles retain the upstream Spinel runtime license.

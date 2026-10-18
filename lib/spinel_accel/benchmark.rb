# frozen_string_literal: true

module SpinelAccel
  class Benchmark
    def initialize(kernel)
      @kernel = kernel
    end

    def run(warmup: 50, rounds: 7, target_ms: 30)
      raise ConfigurationError, 'warmup >= 0, rounds >= 3, and target_ms > 0 required' unless warmup >= 0 && rounds >= 3 && target_ms > 0
      @kernel.check!
      # Timing inputs may differ from the correctness samples, so confirm
      # they agree before measuring them.
      @kernel.bench_inputs.each { |entry, cases| cases.each { |args| @kernel.call(entry, *args, mode: :verify) } }
      rows = @kernel.entries.map do |entry, _|
        workload = @kernel.bench_inputs.key?(entry) ? 'bench_inputs' : 'samples'
        cases = workload == 'bench_inputs' ? @kernel.bench_inputs.fetch(entry) : @kernel.samples.fetch(entry)
        iterations = %w[ruby native].to_h do |mode|
          warmup.times { |i| @kernel.call(entry, *cases[i % cases.length], mode: mode) }
          started = clock
          cases.each { |args| @kernel.call(entry, *args, mode: mode) }
          average = (clock - started) / cases.length
          count = [[(target_ms / 1000.0 / average).ceil, cases.length].max, 20000].min
          [mode, ((count + cases.length - 1) / cases.length) * cases.length]
        end
        samples = { 'ruby' => [], 'native' => [] }
        rounds.times do |round|
          (round.even? ? %w[ruby native] : %w[native ruby]).each do |mode|
            GC.start
            started = clock
            iterations[mode].times { |i| @kernel.call(entry, *cases[i % cases.length], mode: mode) }
            samples[mode] << (clock - started) * 1_000_000 / iterations[mode]
          end
        end
        medians = samples.transform_values { |values| values.sort[values.length / 2] }
        { 'entry' => entry, 'workload' => workload, 'samples_us' => samples, 'median_us' => medians,
          'speedup' => medians['ruby'] / medians['native'], 'iterations' => iterations }
      end
      { 'kernel' => @kernel.name, 'fingerprint' => @kernel.fingerprint, 'abi' => SpinelAccel.abi,
        'ruby' => RUBY_DESCRIPTION, 'yjit' => defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?,
        'scope' => 'boundary validation, data copy and calculation; excludes DB and HTTP',
        'rounds' => rounds, 'warmup' => warmup, 'results' => rows }
    end

    private

    def clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end

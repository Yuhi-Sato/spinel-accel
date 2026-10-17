require_relative 'test_helper'

class NativeTest < Minitest::Test
  def setup
    skip 'Set SPINEL_ROOT or SPINEL_ACCEL_TEST_BUNDLES for real native integration' unless TestKernels.prepare_native!
  end

  def test_all_entries_verify_with_real_native_code
    k = TestKernels::ARITHMETIC
    assert_equal 20, k.check!
    k.entries.each_key { |entry| assert_nil k.native_method(entry).source_location }
    refute_nil k.ruby_method(:sum).source_location
    refute Object.const_defined?(:ExampleArithmetic, false)
    assert_equal '椅子', k.call(:echo, '椅子', mode: :verify)
  end

  def test_nested_modules_and_two_kernels_coexist
    assert_equal 10, TestKernels::NESTED.call(:offset, 3, mode: :verify)
    assert_equal 9, TestKernels::ARITHMETIC.call(:triple, 3, mode: :verify)
    refute_equal TestKernels::NESTED.native_constant, TestKernels::ARITHMETIC.native_constant
    refute Object.const_defined?(:ExampleNested, false)
  end

  def test_seeded_differential_inputs_and_frozen_arrays
    rng = Random.new(20261018)
    100.times do
      values = Array.new(rng.rand(0..200)) { rng.rand(-10000..10000) }.freeze
      assert_equal values.sum, TestKernels::ARITHMETIC.call(:sum, values, mode: :verify)
    end
  end

  def test_exception_class_and_message_are_preserved
    e = assert_raises(ArgumentError) { TestKernels::ARITHMETIC.call(:positive, -1, mode: :verify) }
    assert_equal 'positive value required', e.message
  end

  def test_threads_and_gc_do_not_corrupt_other_kernels
    threads = 4.times.map do
      Thread.new do
        10.times do
          GC.start
          raise 'sum mismatch' unless TestKernels::ARITHMETIC.call(:sum, [1, 2, 3], mode: :verify) == 6
          raise 'nested mismatch' unless TestKernels::NESTED.call(:offset, 3, mode: :verify) == 10
        end
      end
    end
    threads.each(&:value)
    assert true
  end

  def test_boundary_inclusive_benchmark_records_both_engines
    result = SpinelAccel::Benchmark.new(TestKernels::NESTED).run(warmup: 3, rounds: 3, target_ms: 1)
    row = result.fetch('results').first
    assert_equal 3, row.fetch('samples_us').fetch('native').length
    assert_operator row.fetch('speedup'), :>, 0
    assert row.fetch('iterations').values.all? { |count| count % 2 == 0 }
  end

  def test_changed_manifest_is_rejected_without_loading_extension
    library, = TestKernels::ARITHMETIC.artifact
    metadata_file = File.join(File.dirname(library), 'build.json')
    before = File.read(metadata_file)
    begin
      metadata = JSON.parse(before)
      metadata['abi']['version'] = '0.0.0'
      File.write(metadata_file, JSON.generate(metadata))
      assert_raises(SpinelAccel::ArtifactError) { TestKernels::ARITHMETIC.artifact }
    ensure
      File.write(metadata_file, before)
    end
  end
end

require_relative 'test_helper'

class KernelTest < Minitest::Test
  def test_ruby_mode_needs_no_compiler_and_does_not_define_global_module
    assert_equal 6, TestKernels::ARITHMETIC.call(:sum, [1, 2, 3])
    assert_equal 2, TestKernels::NESTED.call(:offset, -5)
    refute Object.const_defined?(:ExampleArithmetic, false)
    refute Object.const_defined?(:ExampleNested, false)
  end

  def test_entry_mode_arity_and_types_are_checked
    k = TestKernels::ARITHMETIC
    assert_raises(SpinelAccel::ConfigurationError) { k.call(:missing, 1) }
    assert_raises(SpinelAccel::ConfigurationError) { k.call(:triple, 1, mode: :auto) }
    assert_raises(SpinelAccel::ContractError) { k.call(:triple) }
    assert_raises(SpinelAccel::ContractError) { k.call(:triple, 1.0) }
    assert_raises(SpinelAccel::ContractError) { k.call(:triple, 1 << 62) }
    assert_raises(SpinelAccel::ContractError) { k.call(:sum, [1, nil]) }
    assert_raises(SpinelAccel::ContractError) { k.call(:sum, Class.new(Array).new([1])) }
    assert_raises(SpinelAccel::ContractError) { k.call(:halve, [Float::NAN]) }
    assert_raises(SpinelAccel::ContractError) { k.call(:negate, 0) }
    assert_raises(SpinelAccel::ContractError) { k.call(:echo, "a\0b") }
    assert_raises(SpinelAccel::ContractError) { k.call(:echo, 'hello'.encode('UTF-16LE')) }
  end

  def test_contract_and_samples_cannot_change_after_fingerprinting
    k = TestKernels::ARITHMETIC
    assert_raises(FrozenError) { k.entries['sum']['params'][0].replace('float_array') }
    assert_raises(FrozenError) { k.samples['shout'][0][0][0].replace('changed') }
  end

  def test_comparison_preserves_float_sign_and_string_encoding
    refute SpinelAccel::Contract.equal?(0.0, -0.0)
    refute SpinelAccel::Contract.equal?('a', 'a'.encode('US-ASCII'))
    assert SpinelAccel::Contract.equal?([1.5, '椅子'], [1.5, '椅子'])
  end

  def test_missing_native_never_falls_back
    Dir.mktmpdir do |dir|
      k = SpinelAccel::Kernel.new(name: 'missing', source: TestKernels::ARITHMETIC.source,
        module_name: 'ExampleArithmetic', cache_dir: dir, entries: { sum: { params: [:integer_array], returns: :integer } })
      assert_raises(SpinelAccel::ArtifactError) { k.call(:sum, [1], mode: :native) }
      assert_equal 1, k.call(:sum, [1], mode: :ruby)
    end
  end

  def test_fingerprint_changes_with_source_and_contract_but_not_source_path
    Dir.mktmpdir do |dir|
      a = File.join(dir, 'a.rb')
      b = File.join(dir, 'b.rb')
      File.write(a, 'module K; def self.run(x); x; end; end')
      FileUtils.cp(a, b)
      make = ->(path) { SpinelAccel::Kernel.new(name: 'k', source: path, module_name: 'K', entries: { run: { params: [:integer], returns: :integer } }) }
      first = make.call(a)
      assert_equal first.fingerprint, make.call(b).fingerprint
      File.write(b, 'module K; def self.run(x); x+1; end; end')
      refute_equal first.fingerprint, make.call(b).fingerprint
    end
  end

  def test_verify_rejects_mutation_and_mismatch_without_touching_caller
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'mutate.rb')
      File.write(file, 'module Mutate; def self.run(a); a << 1; a; end; end')
      k = SpinelAccel::Kernel.new(name: 'mutate', source: file, module_name: 'Mutate', entries: { run: { params: [:integer_array], returns: :integer_array } })
      k.define_singleton_method(:native_method) { |entry| ruby_method(entry) }
      original = [0]
      assert_raises(SpinelAccel::MutationError) { k.call(:run, original, mode: :verify) }
      assert_equal [0], original
      k.define_singleton_method(:native_method) { |_entry| ->(_a) { [9] } }
      # Mutation is reported even if the result also differs.
      assert_raises(SpinelAccel::MutationError) { k.call(:run, original, mode: :verify) }
    end
    k = TestKernels::ARITHMETIC.dup
    k.define_singleton_method(:native_method) { |_entry| ->(_n) { 999 } }
    assert_raises(SpinelAccel::Mismatch) { k.call(:triple, 3, mode: :verify) }
  end

  def test_empty_samples_and_unknown_types_fail_configuration
    k = SpinelAccel::Kernel.new(name: 'empty', source: TestKernels::ARITHMETIC.source,
      module_name: 'ExampleArithmetic', entries: { sum: { params: [:integer_array], returns: :integer } })
    assert_raises(SpinelAccel::ConfigurationError) { k.check! }
    assert_raises(SpinelAccel::ConfigurationError) do
      SpinelAccel::Kernel.new(name: 'invalid', source: k.source, module_name: k.module_name, entries: { sum: { params: [:hash], returns: :integer } })
    end
  end

  def test_array_validators_keep_element_rules
    c = SpinelAccel::Contract
    assert c.valid?('integer_array', [-(1 << 62), 0, (1 << 62) - 1])
    refute c.valid?('integer_array', [0, 1 << 62])
    refute c.valid?('integer_array', [-(1 << 62) - 1])
    refute c.valid?('integer_array', [1, 1.0])
    refute c.valid?('integer_array', [[1]])
    assert c.valid?('float_array', [Float::MAX, Float::MAX])
    refute c.valid?('float_array', [1.0, 1])
    [[Float::NAN], [1.0, Float::NAN, 2.0], [Float::INFINITY, 1.0], [Float::INFINITY, -Float::INFINITY], [-Float::INFINITY]].each do |values|
      refute c.valid?('float_array', values), values.inspect
    end
    assert c.valid?('string_array', ['a', '椅子'])
    refute c.valid?('string_array', ['a', Class.new(String).new('b')])
    refute c.valid?('string_array', ["a\0"])
    e = assert_raises(SpinelAccel::ContractError) { TestKernels::ARITHMETIC.call(:sum, [1, 'x']) }
    assert_equal 'sum argument 0 must be integer_array', e.message
  end

  def test_methods_are_resolved_once_per_kernel
    k = TestKernels::ARITHMETIC
    assert_same k.ruby_method(:sum), k.ruby_method('sum')
    assert_raises(SpinelAccel::ConfigurationError) { k.ruby_method(:missing) }
  end

  def test_default_mode_is_fixed_at_registration
    make = ->(**options) do
      SpinelAccel::Kernel.new(name: 'mode', source: TestKernels::ARITHMETIC.source, module_name: 'ExampleArithmetic',
        cache_dir: Dir.mktmpdir, entries: { sum: { params: [:integer_array], returns: :integer } }, **options)
    end
    assert_raises(SpinelAccel::ArtifactError) { make.call(mode: 'native').call(:sum, [1]) }
    assert_equal 1, make.call(mode: :native).call(:sum, [1], mode: :ruby)
    assert_raises(SpinelAccel::ConfigurationError) { make.call(mode: 'auto') }
  end

  def test_bench_inputs_are_validated_and_used_by_benchmark
    make = ->(inputs) do
      SpinelAccel::Kernel.new(name: 'bench', source: TestKernels::ARITHMETIC.source, module_name: 'ExampleArithmetic',
        entries: { sum: { params: [:integer_array], returns: :integer } }, samples: { sum: [[[1]]] }, bench_inputs: inputs)
    end
    assert_raises(SpinelAccel::ConfigurationError) { make.call(missing: [[[1]]]) }
    assert_raises(SpinelAccel::ConfigurationError) { make.call(sum: [[['x']]]) }
    assert_raises(SpinelAccel::ConfigurationError) { make.call(sum: [[]]) }
    inputs = [[Array.new(64) { |i| i }], [[]], [[5]]]
    k = make.call(sum: inputs)
    assert k.bench_inputs['sum'].frozen?
    k.define_singleton_method(:native_method) { |entry| ruby_method(entry) }
    row = SpinelAccel::Benchmark.new(k).run(warmup: 1, rounds: 3, target_ms: 1).fetch('results').first
    assert_equal 'bench_inputs', row.fetch('workload')
    assert row.fetch('iterations').values.all? { |count| count % inputs.length == 0 }
    # A wrong native result on a benchmark input is rejected before timing.
    k.define_singleton_method(:native_method) { |_entry| ->(values) { values.length == 64 ? -1 : values.sum } }
    assert_raises(SpinelAccel::Mismatch) { SpinelAccel::Benchmark.new(k).run(warmup: 1, rounds: 3, target_ms: 1) }
  end

  def test_subprocess_timeout_and_nonzero_exit_are_visible
    r = SpinelAccel::Command.run([RbConfig.ruby, '-e', '$stdout.sync=true; puts "ready"; sleep 20'], timeout: 0.2)
    assert r['timeout']
    assert_equal 9, r['signal']
    assert_equal "ready\n", r['output']
    r = SpinelAccel::Command.run([RbConfig.ruby, '-e', 'exit 13'])
    assert_equal 13, r['exit']
  end
end

# frozen_string_literal: true
require_relative 'test_helper'

class ArtifactStoreTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @kernel = kernel_named('store')
    @store = SpinelAccel::ArtifactStore.new(@kernel)
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_bundles_are_content_addressed_and_extract_intact
    bundle = publish(stage, version: 'spinel x')
    assert_equal bundle, publish(stage, version: 'spinel x')
    into = Dir.mktmpdir(nil, @dir)
    metadata = @store.extract_bundle(bundle, into: into)
    assert_equal @kernel.fingerprint, metadata.fetch('fingerprint')
    assert_equal 'spinel x', metadata.fetch('compiler_version')
    assert_equal "nested\n", File.read(File.join(into, 'mruby/nested.h'))
    refute File.exist?(File.join(into, 'source.json'))
  end

  def test_extract_rejects_tampered_incomplete_foreign_and_unsafe_bundles
    bundle = publish(stage(tag: 'tampered'))
    File.write(File.join(bundle, 'sp_gc.c'), "changed\n")
    assert_rejected(bundle, /checksum\/path mismatch: sp_gc.c/)

    assert_rejected(publish(stage(without: 'sp_gc.c')), /incomplete/)

    foreign = publish(stage, store: SpinelAccel::ArtifactStore.new(kernel_named('other')))
    assert_rejected(foreign, /different kernel/)

    bundle = publish(stage(tag: 'traversal'))
    File.write(File.join(bundle, '..', 'escape.c'), "gc\n") # exists and matches, but lies outside the bundle
    rewrite_metadata(bundle) { |m| m['files']['../escape.c'] = m['files'].fetch('sp_gc.c') }
    assert_rejected(bundle, /mismatch: \.\.\/escape.c/)

    bundle = publish(stage(tag: 'symlink'))
    FileUtils.mv(File.join(bundle, 'spinel_rt.h'), File.join(bundle, 'real.h'))
    File.symlink(File.join(bundle, 'real.h'), File.join(bundle, 'spinel_rt.h'))
    assert_rejected(bundle, /mismatch: spinel_rt.h/)

    File.write(File.join(bundle, 'source.json'), '{')
    assert_rejected(bundle, /invalid source bundle/)
    assert_rejected(File.join(@dir, 'missing'), /invalid source bundle/)
  end

  def test_install_switches_current_library_and_checks_integrity
    bundle = publish(stage)
    first = install(bundle, "first\n")
    library, metadata = @store.current_library
    assert_equal first, File.dirname(library)
    assert_equal Digest::SHA256.hexdigest("first\n"), metadata.fetch('extension_sha256')
    assert_equal SpinelAccel.abi, metadata.fetch('abi')
    refute metadata.key?('files')

    second = install(bundle, "second\n")
    assert_equal second, File.dirname(@store.current_library.first)

    File.write(@store.current_library.first, "tampered\n")
    assert_raises_message(/checksum mismatch/) { @store.current_library }

    build = File.join(second, 'build.json')
    File.write(File.join(second, File.basename(library)), "second\n")
    File.write(build, JSON.generate(JSON.parse(File.read(build)).merge('abi' => {})))
    assert_raises_message(/ABI mismatch: store; rebuild/) { @store.current_library }
  end

  def test_missing_or_corrupt_pointer_is_unavailable
    assert_raises_message(/store: native artifact unavailable/) { @store.current_library }
    install(publish(stage), "lib\n")
    pointer = Dir[File.join(@kernel.root, 'native', '*', 'current.json')].first
    # A copy under another identifier passes its own build.json check but not
    # the identifier-to-checksum binding.
    impostor = File.join(File.dirname(pointer), 'f' * 64)
    FileUtils.cp_r(File.dirname(@store.current_library.first), impostor)
    File.write(pointer, JSON.generate('artifact' => 'f' * 64))
    assert_raises_message(/checksum mismatch/) { @store.current_library }
    File.write(pointer, JSON.generate('artifact' => '../../etc'))
    assert_raises_message(/invalid artifact identifier/) { @store.current_library }
  end

  private

  def kernel_named(name)
    SpinelAccel::Kernel.new(name: name, source: TestKernels::ARITHMETIC.source, module_name: 'ExampleArithmetic',
      cache_dir: File.join(@dir, 'cache'), entries: { triple: { params: [:integer], returns: :integer } })
  end

  # Bundles are content-addressed, so scenarios that tamper with one pass a
  # distinct tag to get their own copy.
  def stage(without: nil, tag: nil)
    dir = Dir.mktmpdir('stage-', @dir)
    f = @kernel.feature
    files = { 'tag' => "#{tag}\n", "#{f}.c" => "c\n", "#{f}_ext.c" => "ext\n", "#{f}.h" => "h\n", 'sp_gc.c' => "gc\n",
              'spinel_rt.h' => "rt\n", 'SPINEL_LICENSE' => "license\n", 'mruby/nested.h' => "nested\n" }
    files.except(without).each do |path, text|
      FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
      File.write(File.join(dir, path), text)
    end
    dir
  end

  def publish(stage, store: @store, version: 'spinel test')
    store.publish_bundle(stage, compiler_sha256: 'c0ffee', compiler_version: version)
  end

  def install(bundle, library_bytes)
    into = Dir.mktmpdir('compile-', @dir)
    metadata = @store.extract_bundle(bundle, into: into)
    File.write(File.join(into, "#{@kernel.feature}.#{RbConfig::CONFIG.fetch('DLEXT')}"), library_bytes)
    @store.install(into, bundle: bundle, metadata: metadata, build_seconds: 0.1)
  end

  def rewrite_metadata(bundle)
    path = File.join(bundle, 'source.json')
    metadata = JSON.parse(File.read(path))
    yield metadata
    File.write(path, JSON.generate(metadata))
  end

  def assert_rejected(bundle, pattern)
    assert_raises_message(pattern) { @store.extract_bundle(bundle, into: Dir.mktmpdir(nil, @dir)) }
  end

  def assert_raises_message(pattern, &block)
    e = assert_raises(SpinelAccel::ArtifactError, &block)
    assert_match pattern, e.message
  end
end

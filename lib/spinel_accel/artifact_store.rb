# frozen_string_literal: true

require 'fileutils'

module SpinelAccel
  # Owns the layout of a kernel's cache root and the integrity rules for what
  # is stored there:
  #
  #   bundles/<sha256 of source.json>/      portable C sources and source.json
  #   native/<abi_key>/current.json         pointer to the active extension
  #   native/<abi_key>/<extension sha256>/  extension, build.json, SPINEL_LICENSE
  class ArtifactStore
    BUNDLE_FORMAT = 1
    ARTIFACT_ID = /\A[0-9a-f]{64}\z/
    BUNDLE_PATH = /\A[\w.\/-]+\z/

    def initialize(kernel)
      @kernel = kernel
    end

    # Records checksums for every file in stage and copies it into the cache.
    def publish_bundle(stage, compiler_sha256:, compiler_version:)
      files = Dir[File.join(stage, '**/*')].select { |p| File.file?(p) }.sort.to_h do |path|
        [path.delete_prefix(stage + '/'), Digest::SHA256.file(path).hexdigest]
      end
      metadata = { 'format' => BUNDLE_FORMAT, 'fingerprint' => @kernel.fingerprint, 'spinel_pin' => PIN,
                   'compiler_sha256' => compiler_sha256, 'compiler_version' => compiler_version, 'files' => files }
      File.write(File.join(stage, 'source.json'), JSON.pretty_generate(metadata) + "\n")
      key = Digest::SHA256.file(File.join(stage, 'source.json')).hexdigest
      destination = File.join(@kernel.root, 'bundles', key)
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp_r(stage, destination) unless File.exist?(destination)
      destination
    end

    # Verifies a bundle (possibly emitted elsewhere) and copies its files into
    # the directory `into`.
    def extract_bundle(bundle, into:)
      metadata = verified_bundle_metadata(bundle)
      metadata.fetch('files').each_key do |path|
        target = File.join(into, path)
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp(File.join(bundle, path), target)
      end
      metadata
    rescue JSON::ParserError, KeyError, Errno::ENOENT => e
      raise ArtifactError, "invalid source bundle: #{e.message}"
    end

    # Stores the extension built in stage and makes it current.
    def install(stage, bundle:, metadata:, build_seconds:)
      sha = Digest::SHA256.file(File.join(stage, library_name)).hexdigest
      target = File.join(native_dir, sha)
      FileUtils.mkdir_p(target)
      FileUtils.cp(File.join(stage, library_name), File.join(target, library_name)) unless File.exist?(File.join(target, library_name))
      FileUtils.cp(File.join(stage, 'SPINEL_LICENSE'), target)
      build = metadata.reject { |key, _| key == 'files' }.merge('abi' => SpinelAccel.abi,
        'extension_sha256' => sha, 'gem_version' => VERSION, 'ruby' => RUBY_DESCRIPTION,
        'source_bundle_sha256' => Digest::SHA256.file(File.join(bundle, 'source.json')).hexdigest,
        'build_seconds' => build_seconds)
      File.write(File.join(target, 'build.json'), JSON.pretty_generate(build) + "\n")
      point_current_to(sha)
      target
    end

    # Returns the current extension and its build metadata after checking that
    # it belongs to this kernel and Ruby ABI and has not been modified.
    def current_library
      id = JSON.parse(File.read(current_pointer)).fetch('artifact')
      raise ArtifactError, 'invalid artifact identifier' unless id.match?(ARTIFACT_ID)
      dir = File.join(native_dir, id)
      metadata = JSON.parse(File.read(File.join(dir, 'build.json')))
      unless metadata.fetch('fingerprint') == @kernel.fingerprint && metadata.fetch('abi') == SpinelAccel.abi && metadata.fetch('spinel_pin') == PIN
        raise ArtifactError, "stale kernel or Ruby ABI mismatch: #{@kernel.name}; rebuild"
      end
      library = File.join(dir, library_name)
      actual = Digest::SHA256.file(library).hexdigest
      raise ArtifactError, 'extension checksum mismatch' unless actual == id && actual == metadata.fetch('extension_sha256')
      [library, metadata]
    rescue Errno::ENOENT, JSON::ParserError, KeyError => e
      raise ArtifactError, "#{@kernel.name}: native artifact unavailable; run spinel-accel build (#{e.message})"
    end

    private

    def native_dir
      File.join(@kernel.root, 'native', SpinelAccel.abi_key)
    end

    def current_pointer
      File.join(native_dir, 'current.json')
    end

    def library_name
      "#{@kernel.feature}.#{RbConfig::CONFIG.fetch('DLEXT')}"
    end

    def required_bundle_files
      f = @kernel.feature
      ["#{f}.c", "#{f}_ext.c", "#{f}.h", 'sp_gc.c', 'spinel_rt.h', 'SPINEL_LICENSE']
    end

    def verified_bundle_metadata(bundle)
      metadata = JSON.parse(File.read(File.join(bundle, 'source.json')))
      unless metadata.fetch('format') == BUNDLE_FORMAT && metadata.fetch('fingerprint') == @kernel.fingerprint && metadata.fetch('spinel_pin') == PIN
        raise ArtifactError, 'source bundle belongs to a different kernel or compiler pin'
      end
      files = metadata.fetch('files')
      raise ArtifactError, 'source bundle is incomplete' unless (required_bundle_files - files.keys).empty?
      files.each do |path, hash|
        raise ArtifactError, "source bundle checksum/path mismatch: #{path}" unless intact_bundle_file?(bundle, path, hash)
      end
      metadata
    end

    def intact_bundle_file?(bundle, path, hash)
      full = File.join(bundle, path)
      path.match?(BUNDLE_PATH) && !path.split('/').include?('..') && !path.start_with?('/') &&
        File.file?(full) && !File.symlink?(full) && Digest::SHA256.file(full).hexdigest == hash
    end

    def point_current_to(sha)
      temporary = "#{current_pointer}.#{Process.pid}.tmp"
      File.write(temporary, JSON.generate('artifact' => sha) + "\n")
      File.rename(temporary, current_pointer)
    end
  end
end

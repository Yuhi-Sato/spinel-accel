# frozen_string_literal: true

require 'json'
require 'digest'
require 'rbconfig'
require_relative 'spinel_accel/version'

module SpinelAccel
  PIN = '72e45de6e5411b98e8efbdf468e6660495026dc5'
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ContractError < Error; end
  class ArtifactError < Error; end
  class BuildError < Error; end
  class Mismatch < Error; end
  class MutationError < Error; end

  def self.abi
    { 'engine' => RUBY_ENGINE, 'version' => RUBY_VERSION, 'patchlevel' => RUBY_PATCHLEVEL,
      'arch' => RbConfig::CONFIG.fetch('arch'), 'host_os' => RbConfig::CONFIG.fetch('host_os'),
      'ruby_api' => RbConfig::CONFIG.fetch('ruby_version') }
  end

  def self.abi_key
    Digest::SHA256.hexdigest(JSON.generate(abi))[0, 16]
  end

  def self.register(name, **options)
    @kernels ||= {}
    key = name.to_s
    raise ConfigurationError, "duplicate kernel: #{key}" if @kernels.key?(key)
    @kernels[key] = Kernel.new(name: key, **options)
  end

  def self.kernels
    (@kernels || {}).dup
  end
end

require_relative 'spinel_accel/contract'
require_relative 'spinel_accel/kernel'
require_relative 'spinel_accel/artifact_store'
require_relative 'spinel_accel/command'
require_relative 'spinel_accel/builder'
require_relative 'spinel_accel/benchmark'

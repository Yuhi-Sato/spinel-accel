# frozen_string_literal: true
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'open3'
require_relative '../lib/spinel_accel'

module TestKernels
  ROOT = File.expand_path('..', __dir__)
  CACHE = ENV.fetch('SPINEL_ACCEL_TEST_CACHE') { Dir.mktmpdir('spinel accel tests ') }
  ARITHMETIC = SpinelAccel::Kernel.new(name: 'arithmetic', source: File.join(__dir__, 'fixtures/arithmetic.rb'),
    module_name: 'ExampleArithmetic', cache_dir: CACHE,
    entries: {
      sum: { params: [:integer_array], returns: :integer },
      triple: { params: [:integer], returns: :integer },
      halve: { params: [:float_array], returns: :float_array },
      shout: { params: [:string_array], returns: :string_array },
      negate: { params: [:boolean], returns: :boolean },
      echo: { params: [:string], returns: :string },
      positive: { params: [:integer], returns: :integer },
      scale: { params: [:float], returns: :float },
      shift: { params: [:integer_array], returns: :integer_array },
      constant: { params: [], returns: :integer }
    },
    samples: { sum: [[[1, 2, 3]], [[]], [[-3, 0, 3]]], triple: [[0], [7]],
               halve: [[[1.0, -2.0]], [[]]], shout: [[['hi', 'hello']], [[]]],
               negate: [[true], [false]], echo: [['hello'], ['椅子']], positive: [[1], [7]],
               scale: [[-4.0], [0.5]], shift: [[[1, -2]], [[]]], constant: [[]] })
  NESTED = SpinelAccel::Kernel.new(name: 'nested', source: File.join(__dir__, 'fixtures/namespaced.rb'),
    module_name: 'ExampleNested::Math', cache_dir: CACHE,
    entries: { offset: { params: [:integer], returns: :integer } }, samples: { offset: [[0], [-5]] })

  def self.prepare_native!
    return true if @prepared
    if ENV['SPINEL_ACCEL_TEST_BUNDLES']
      manifest = File.expand_path(ENV.fetch('SPINEL_ACCEL_TEST_BUNDLES'))
      bundles = JSON.parse(File.read(manifest))
      [ARITHMETIC, NESTED].each do |kernel|
        SpinelAccel::Builder.new(kernel).compile(bundle: File.expand_path(bundles.fetch(kernel.name), File.dirname(manifest)))
      end
    elsif ENV['SPINEL_ROOT']
      [ARITHMETIC, NESTED].each { |kernel| SpinelAccel::Builder.new(kernel).build }
    else
      return false
    end
    @prepared = true
  end
end

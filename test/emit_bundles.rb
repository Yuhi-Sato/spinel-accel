# frozen_string_literal: true
require_relative 'test_helper'

destination = File.expand_path('../tmp/native-test-bundles', __dir__)
FileUtils.mkdir_p(destination)
manifest = [TestKernels::ARITHMETIC, TestKernels::NESTED].to_h do |kernel|
  source = SpinelAccel::Builder.new(kernel).emit
  target = File.join(destination, kernel.name)
  FileUtils.mkdir_p(target)
  metadata = JSON.parse(File.read(File.join(source, 'source.json')))
  (metadata.fetch('files').keys + ['source.json']).each do |path|
    file = File.join(target, path)
    FileUtils.mkdir_p(File.dirname(file))
    FileUtils.cp(File.join(source, path), file)
  end
  [kernel.name, kernel.name]
end
File.write(File.join(destination, 'bundles.json'), JSON.pretty_generate(manifest) + "\n")
puts destination

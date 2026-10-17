# frozen_string_literal: true
require_relative 'lib/spinel_accel/version'

Gem::Specification.new do |spec|
  spec.name = 'spinel_accel'
  spec.version = SpinelAccel::VERSION
  spec.authors = ['Yuhi-Sato']
  spec.email = ['yuhi120101@gmail.com']
  spec.summary = 'Build and verify pure Ruby computation kernels with Spinel'
  spec.description = 'Explicit Ruby/native/verify execution, pinned ahead-of-time builds, portable C bundles, and reproducible benchmarks for CRuby applications.'
  spec.license = 'MIT'
  spec.homepage = 'https://github.com/Yuhi-Sato/spinel-accel'
  spec.metadata = { 'source_code_uri' => spec.homepage, 'rubygems_mfa_required' => 'true' }
  spec.required_ruby_version = '>= 3.3'
  spec.files = Dir.chdir(__dir__) { Dir['lib/**/*.rb', 'exe/*', 'examples/**/*', 'README.md', 'VALIDATION.md', 'LICENSE', 'CHANGELOG.md'].select { |p| File.file?(p) }.sort }
  spec.bindir = 'exe'
  spec.executables = ['spinel-accel']
  spec.require_paths = ['lib']
end

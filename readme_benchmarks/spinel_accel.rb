# frozen_string_literal: true

require 'spinel_accel'

# Ports of the benchmarks listed in Spinel's README, as spinel-accel kernels.
# Each benchmark registers itself from registrations/<name>.rb.
Dir[File.expand_path('registrations/*.rb', __dir__)].sort.each { |path| require path }

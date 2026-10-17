# frozen_string_literal: true

require 'open3'
require 'timeout'

module SpinelAccel
  module Command
    def self.run(argv, dir: Dir.pwd, timeout: 120)
      output = +''
      status = nil
      expired = false
      Open3.popen2e(*argv, chdir: dir, pgroup: true) do |stdin, stream, waiter|
        stdin.close
        reader = Thread.new { stream.read }
        begin
          Timeout.timeout(timeout) { status = waiter.value; output = reader.value }
        rescue Timeout::Error
          expired = true
          begin
            Process.kill('KILL', -waiter.pid)
          rescue Errno::ESRCH
            # Already exited.
          end
          status = waiter.value
        ensure
          output = reader.value
        end
      end
      { 'argv' => argv, 'exit' => status.exitstatus, 'signal' => status.termsig, 'timeout' => expired, 'output' => output }
    end

    def self.run!(argv, dir:, log:, timeout: 120)
      result = run(argv, dir: dir, timeout: timeout)
      File.open(log, 'a') { |file| file.puts(JSON.generate(result)) }
      unless result['exit'] == 0 && !result['timeout']
        raise BuildError, "command failed (exit=#{result['exit']}, signal=#{result['signal']}, timeout=#{result['timeout']}); see #{log}\n#{result['output'].lines.last(6).join}"
      end
      result
    rescue Errno::ENOENT => e
      raise BuildError, e.message
    end
  end
end

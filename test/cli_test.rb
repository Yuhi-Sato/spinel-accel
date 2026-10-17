require_relative 'test_helper'

class CLITest < Minitest::Test
  def command(*args)
    Open3.capture3(RbConfig.ruby, '-I', File.join(TestKernels::ROOT, 'lib'), File.join(TestKernels::ROOT, 'exe/spinel-accel'), *args)
  end

  def test_init_creates_runnable_manifest_and_refuses_overwrite
    Dir.mktmpdir do |dir|
      target = File.join(dir, 'demo')
      stdout, stderr, status = command('init', target)
      assert status.success?, stderr
      assert_equal target, JSON.parse(stdout)['created']
      _, stderr, status = command('init', target)
      refute status.success?
      assert_includes stderr, 'already exists'
      _, stderr, status = command('check', 'demo', '--config', File.join(target, 'spinel_accel.rb'), '--cache-dir', File.join(dir, 'cache'))
      refute status.success?
      assert_includes stderr, 'native artifact unavailable'
    end
  end

  def test_doctor_missing_compiler_and_bad_options_are_nonzero
    stdout, _, status = command('doctor', '--spinel-root', '/nonexistent')
    refute status.success?
    refute JSON.parse(stdout)['ok']
    _, _, status = command('build', '--invalid')
    refute status.success?
  end

  def test_version_and_help_work_without_a_manifest
    stdout, _, status = command('--version')
    assert status.success?
    assert_equal SpinelAccel::VERSION, stdout.strip
    stdout, _, status = command('--help')
    assert status.success?
    assert_includes stdout, 'Usage:'
  end
end

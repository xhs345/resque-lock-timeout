require File.dirname(__FILE__) + '/test_helper'

class LockTest < Test::Unit::TestCase
  def setup
    $acquired = $success = $lock_failed = 0
    Resque.redis.flushall
    @worker = Resque::Worker.new(:test)
  end

  def test_lint
    assert_nothing_raised do
      Resque::Plugin.lint(Resque::Plugins::Lock)
    end
  end

  def test_version
    major, minor, patch = Resque::Version.split('.')
    assert_equal 1, major.to_i
    assert minor.to_i >= 7
  end

  def test_can_acquire_lock
    SlowJob.acquire_lock
    assert_equal true, SlowJob.locked?, 'lock should be acquired'
  end

  def test_can_release_lock
    SlowJob.acquire_lock
    assert_equal true, SlowJob.locked?, 'lock should be acquired'

    SlowJob.release_lock
    assert_equal false, SlowJob.locked?, 'lock should have been released'
  end

  def test_lock_acquired_callback
    FastJob.acquire_lock

    assert_equal true, FastJob.locked?, 'lock should be acquired'
    assert_equal 1, $acquired, 'job should increment aquired'
  end

  def test_lock_failed_callback
    FastJob.acquire_lock
    assert_equal true, FastJob.locked?, 'lock should be acquired'

    FastJob.acquire_lock
    assert_equal 1, $lock_failed, 'job callback should increment lock_failed'
  end

  def test_lock_without_timeout
    3.times { Resque.enqueue(SlowJob) }

    workers = []
    3.times do
      workers << Thread.new { @worker.process }
    end
    workers.each { |t| t.join }

    assert_equal 1, $success, 'job should increment success'
  end

  def test_lock_is_released_on_success
    Resque.enqueue(FastJob)
    @worker.process
    assert_equal 1, $success, 'job should increment success'
    assert_equal false, FastJob.locked?, 'lock should have been released'
  end

  def test_lock_is_released_on_failure
    Resque.enqueue(FailingFastJob)
    @worker.process
    assert_equal 0, $success, 'job shouldnt increment success'
    assert_equal false, FastJob.locked?, 'lock should have been released'
  end

end

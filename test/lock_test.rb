require 'test/unit'
require 'resque'
require 'resque/plugins/lock'

class SlowJob
  extend Resque::Plugins::Lock
  @queue = :test

  def self.perform
    $success += 1
    sleep 0.2
  end
end

class FastJob
  extend Resque::Plugins::Lock
  @queue = :test

  def self.perform
    $success += 1
  end

  def self.lock_acquired(recovered, *args)
    $acquired += 1
    $locked += 1
    $recovered = recovered
  end
end

class FailingFastJob
  extend Resque::Plugins::Lock
  @queue = :test

  def self.perform
    raise
    $success += 1
  end
end

class SlowerWithTimeoutJob
  extend Resque::Plugins::Lock
  @queue = :test
  @lock_timeout = 1

  def self.perform
    $success += 1
    sleep 3
  end
end

def ExpireBeforeReleaseJob
  extend Resque::Plugins::Lock
  @queue = :test

  def self.lock_expired_before_release(*args)
    $lock_expired = true
  end
end

class LockTest < Test::Unit::TestCase
  def setup
    $acquired = $success = $locked = 0
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
    Resque.enqueue(FastJob)
    @worker.process

    assert_equal 1, $success, 'job should increment success'
    assert_equal 1, $acquired, 'job should increment aquired'
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

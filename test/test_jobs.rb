class SlowJob
  extend Resque::Plugins::Lock
  @queue = :test

  def self.perform
    $success += 1
    sleep 0.2
  end

  def self.lock_failed(*args)
    $lock_failed += 1
  end
end

class FastJob
  extend Resque::Plugins::Lock
  @queue = :test

  def self.perform
    $success += 1
  end

  def self.lock_failed(*args)
    $lock_failed += 1
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

class SlowWithTimeoutJob
  extend Resque::Plugins::Lock
  @queue = :test
  @lock_timeout = 60

  def self.perform
    $success += 1
    sleep 0.2
  end
end

class ExpireBeforeReleaseJob
  extend Resque::Plugins::Lock
  @queue = :test
  @lock_timeout = 1

  def self.perform
    $success += 1
    sleep 2
  end

  def self.lock_expired_before_release
    $lock_expired = true
  end
end
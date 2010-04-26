module Resque
  module Plugins
    # If you want only one instance of your job running at a time,
    # extend it with this module:
    #
    # require 'resque/plugins/lock'
    #
    # class UpdateNetworkGraph
    #   extend Resque::Plugins::Lock
    #
    #   def self.perform(repo_id)
    #     heavy_lifting
    #   end
    # end
    #
    # While other UpdateNetworkGraph jobs will be placed on the queue,
    # the Lock class will check Redis to see if any others are
    # executing with the same arguments before beginning. If another
    # is executing the job will be aborted.
    #
    # If you want to define the key yourself you can override the
    # `identifier` or `lock` method in your subclass, e.g.
    #
    # class UpdateNetworkGraph
    #   extend Resque::Plugins::Lock
    #
    #   # Run only one at a time, regardless of repo_id.
    #   def self.identifier(repo_id)
    #     "network-graph"
    #   end
    #
    #   def self.perform(repo_id)
    #     heavy_lifting
    #   end
    # end
    #
    # The above modification will ensure only one job of class
    # UpdateNetworkGraph is running at a time, regardless of the
    # repo_id. Normally a job is locked using a combination of its
    # class name and arguments.
    #
    # If you wish to limit the duration a lock may be held for, you can
    # set/override `lock_timeout`. e.g.
    #
    # class UpdateNetworkGraph
    #   extend Resque::Plugins::Lock
    #
    #   # lock may be held for upto an hour.
    #   @lock_timeout = 3600
    #
    #   def self.perform(repo_id)
    #     heavy_lifting
    #   end
    # end
    #
    # Several callbacks are available to override and implement
    # your own logic, e.g.
    #
    # class UpdateNetworkGraph
    #   extend Resque::Plugins::Lock
    #
    #   # Lock may be held for upto an hour.
    #   @lock_timeout = 3600
    #
    #   # Job failed to acquire lock. You may implement retry or other logic.
    #   def self.lock_failed(repo_id)
    #     retry_using_delay
    #   end
    #
    #   # Job has complete; but the lock expired before we could relase it.
    #   # The lock wasn't released; as its *possible* the lock is now held
    #   # by another job.
    #   def self.lock_expired_before_release(repo_id)
    #     handle_if_needed
    #   end
    #
    #   def self.perform(repo_id)
    #     heavy_lifting
    #   end
    # end
    #
    module Lock
      # Override to control the identifier for this job, used
      # as part of the Redis lock key. It is passed the
      # job arguments.
      def identifier(*args)
        args.join('-')
      end
      
      # Override to fully control the key used. It is passed
      # the job arguments.
      #
      # The default looks like this: 'lock:<class name>:<identifier>'
      def lock(*args)
        ['lock', name, identifier(*args)].compact.join(":")
      end

      # Number of seconds the lock may be held for.
      # A value of 0 or below will lock without a timeout.
      def lock_timeout
        @lock_timeout ||= 0
      end

      # Try to acquire a lock.
      def acquire_lock!(*args)
        acquired = false
        lock_key = lock(*args)

        unless lock_timeout > 0
          # Acquire without using a timeout.
          acquired = true if Resque.redis.setnx(lock_key, true)
        else
          # Acquire using the timeout algorithm.
          acquired, lock_until = acquire_lock_algorithm!(lock_key)
        end

        lock_failed(*args) if !acquired && respond_to?(:lock_failed)
        lock_until && acquired ? lock_until : acquired
      end

      # Locking algorithm: http://code.google.com/p/redis/wiki/SetnxCommand
      def acquire_lock_algorithm!(lock_key)
        now = Time.now.to_i
        lock_until = now + lock_timeout
        acquired = false

        return [true, lock_until] if Resque.redis.setnx(lock_key, lock_until)
        # Can't acquire the lock, see if it has expired.
        lock_expiration = Resque.redis.get(lock_key)
        if lock_expiration && lock_expiration.to_i < now
          # expired, try to acquire.
          lock_expiration = Resque.redis.getset(lock_key, lock_until)
          if lock_expiration.nil? || lock_expiration.to_i < now
            acquired = true
          end
        else
          # Try once more...
          acquired = true if Resque.redis.setnx(lock_key, lock_until)
        end

        [acquired, lock_until]
      end

      # Release the lock.
      def release_lock!(*args)
        Resque.redis.del(lock(*args))
      end

      # Convenience method, not used internally.
      def locked?(*args)
        Resque.redis.exists(lock(*args))
      end

      # Where the magic happens.
      def around_perform_lock(*args)
        # Abort if another job holds the lock.
        return unless lock_until = acquire_lock!(*args)

        begin
          yield
        ensure
          # Release the lock on success and error. Unless a lock_timeout is
          # used, then we need to be more careful before releasing the lock.
          unless lock_until === true
            now = Time.now.to_i
            if lock_until < now && respond_to?(:lock_expired_before_release)
              # Eeek! Lock expired before perform finished. Trigger callback.
              lock_expired_before_release(*args)
              return # dont relase lock.
            end
          end
          release_lock!(*args)
        end
      end

    end

  end
end

module Resque
  module Plugins
    # If you want only one instance of your job running at a time,
    # extend it with this module.
    #
    # For example:
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
    # `lock` class method in your subclass, e.g.
    #
    # class UpdateNetworkGraph
    #   extend Resque::Plugins::Lock
    #
    #   # Run only one at a time, regardless of repo_id.
    #   def self.lock(repo_id)
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
    module Lock
      # Override in your job to control the lock key. It is
      # passed the same arguments as `perform`, that is, your job's
      # payload.
      def lock(*args)
        "lock:#{name}-#{args.to_s}"
      end

      # Number of seconds the lock may be held for.
      # A value of 0 or below will lock without a timeout.
      def lock_timeout
        @lock_timeout ||= 0
      end

      # Locking algorithm: http://code.google.com/p/redis/wiki/SetnxCommand
      def acquire_lock!(*args)
        lock_acquired = false
        lock_key = lock(*args)

        unless lock_timeout > 0
          # Acquire without using a timeout.
          lock_acquired = true if Resque.redis.setnx(lock_key, true)
        else
          # Acquire using a timestamp.
          now = Time.now.to_i
          lock_until = now + lock_timeout

          if Resque.redis.setnx(lock_key, lock_until)
            lock_acquired = true
          else
            # If we can't acquire the lock, see if it has expired.
            lock_expiration = Resque.redis.get(lock_key)
            if lock_expiration && lock_expiration.to_i < now
              # expired, try to acquire.
              lock_expiration = Resque.redis.getset(lock_key, lock_until)
              if lock_expiration.nil? || lock_expiration.to_i < now
                lock_acquired = true
              end
            else
              # Try once more...
              lock_acquired = true if Resque.redis.setnx(lock_key, lock_until)
            end
          end
        end

        lock_failed(*args) if !lock_acquired && respond_to?(:lock_failed)
        lock_until && lock_acquired ? lock_until : lock_acquired
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
          now = Time.now.to_i
          release = false

          if lock_until == true
            release = true
          else
            if lock_until < now && respond_to?(:lock_expired_before_release)
              # Eeek! Lock expired before perform finished. Trigger callback.
              lock_expired_before_release(*args)
            else
              release = true
            end
          end

          release_lock!(*args) if release
        end
      end
    end
  end
end

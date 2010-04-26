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

      # Try to acquire the lock.
      def acquire_lock!(*args)
        lock_acquired = false
        lock_key = lock(*args)

        unless lock_timeout > 0
          # acquire without using a timeout.
          lock_acquired = true if Resque.redis.setnx(lock_key, true)
        else
          # acquire using a timestamp.
          now = Time.now.to_i
          lock_for = now + lock_timeout
          
          if Resque.redis.setnx(lock_key, lock_for)
            lock_acquired = true
          else
            # If we can't acquire the lock, see if it has expired.
            locked_until = Resque.redis.get(lock_key)
            if locked_until
              if locked_until.to_i < now
                locked_until = Resque.redis.getset(lock_key, lock_for)
                if locked_until.nil? or locked_until.to_i < now
                  lock_acquired = true
                end
              end
            else
              lock_acquired = true
            end
          end
        end
        
        lock_failed(*args) if lock_acquired == false && respond_to?(:lock_failed)
        lock_acquired
      end

      # Release the lock.
      def release_lock!(*args)
        # check if the timeout has expired first.
        Resque.redis.del(lock(*args))
      end

      # Convenience method, not used internally.
      def locked?(*args)
        Resque.redis.exists(lock(*args))
      end

      # Where the magic happens.
      def around_perform_lock(*args)
        # Abort if another job holds the lock.
        return unless acquire_lock!(*args)

        begin
          yield
        ensure
          # Always clear the lock when we're done, even if there is an
          # error.
          release_lock!(*args)
        end
      end
    end
  end
end

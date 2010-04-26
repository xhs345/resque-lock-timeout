Resque Lock
===========

A [Resque][rq] plugin. Requires Resque 1.7.0.

If you want only one instance of your job running at a time, extend it
with this module.

Usage
-----

### Single Job Instance

    require 'resque/plugins/lock'

    class UpdateNetworkGraph
      extend Resque::Plugins::Lock

      def self.perform(repo_id)
        heavy_lifting
      end
    end

While other UpdateNetworkGraph jobs will be placed on the queue,
the Locked class will check Redis to see if any others are
executing with the same arguments before beginning. If another
is executing the job will be aborted, if defined `lock_failed`
will be called with the job arguments.

### Custom Lock Key

If you want to define the key yourself you can override the
`lock` class method in your subclass, e.g.

    class UpdateNetworkGraph
      extend Resque::Plugins::Lock

      # Run only one at a time, regardless of repo_id.
      def self.lock(repo_id)
        'network-graph'
      end

      def self.perform(repo_id)
        heavy_lifting
      end
    end

The above modification will ensure only one job of class
UpdateNetworkGraph is running at a time, regardless of the
repo_id. Normally a job is locked using a combination of its
class name and arguments.

### With Lock Expiry/Timeout

The locking algorithm used can be found in the [Redis SETNX][redis-setnx]
documentation.

Simply set the lock timeout in seconds, e.g.

    class UpdateNetworkGraph
      extend Resque::Plugins::Lock

      # Lock may be held for upto an hour.
      @lock_timeout = 3600

      def self.perform(repo_id)
        heavy_lifting
      end
    end

### Callback Methods

Several callbacks are available to override and implement
your own logic, e.g.

    class UpdateNetworkGraph
      extend Resque::Plugins::Lock

      # Lock may be held for upto an hour.
      @lock_timeout = 3600

      # Job failed to acquire lock. You may implement retry or other logic.
      def self.lock_failed(repo_id)
        retry_using_delay
      end

      # Job has complete; but the lock expired before we could relase it.
      # The lock wasn't released; as its *possible* the lock is now held
      # by another job.
      def self.lock_expired_before_release(repo_id)
        handle_if_needed
      end

      def self.perform(repo_id)
        heavy_lifting
      end
    end

Install
=======

    $ gem install resque-exponential-backoff

[rq]: http://github.com/defunkt/resque
[redis-setnx]: http://code.google.com/p/redis/wiki/SetnxCommand

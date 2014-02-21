dir = File.dirname(File.expand_path(__FILE__))
$LOAD_PATH.unshift dir + '/../lib'
$TESTING = true

# Run code coverage in MRI 1.9 only.
if RUBY_VERSION >= '1.9' && RUBY_ENGINE == 'ruby'
  require 'simplecov'
  SimpleCov.start do
    add_filter '/test/'
  end
end

require 'minitest/pride'
require 'minitest/autorun'

require 'resque-lock-timeout'
require dir + '/test_jobs'

# make sure we can run redis-server
if !system('which redis-server')
  puts '', "** `redis-server` was not found in your PATH"
  abort ''
end

# make sure we can shutdown the server using cli.
if !system('which redis-cli')
  puts '', "** `redis-cli` was not found in your PATH"
  abort ''
end

puts "Starting redis for testing at localhost:9737..."

# Start redis server for testing.
`redis-server #{dir}/redis-test.conf`
Resque.redis = '127.0.0.1:9737'

# After tests are complete, make sure we shutdown redis.
Minitest.after_run {
  `redis-cli -p 9737 shutdown nosave`
}

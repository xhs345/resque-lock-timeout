dir = File.dirname(File.expand_path(__FILE__))
$LOAD_PATH.unshift dir + '/../lib'
$TESTING = true

require 'rubygems'
require 'minitest/unit'
require 'minitest/pride'

# Run code coverage in MRI 1.9 only.
if RUBY_VERSION >= '1.9' && RUBY_ENGINE == 'ruby'
  require 'simplecov'
  SimpleCov.start do
    add_filter '/test/'
  end
end

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

# This code is run `at_exit` to setup everything before running the tests.
# Redis server is started before this code block runs.
at_exit do
  next if $!

  exit_code = MiniTest::Unit.new.run(ARGV)
  `redis-cli -p 9737 shutdown nosave`
end

puts "Starting redis for testing at localhost:9737..."
`redis-server #{dir}/redis-test.conf`
Resque.redis = '127.0.0.1:9737'

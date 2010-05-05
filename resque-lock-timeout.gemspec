Gem::Specification.new do |s|
  s.name              = 'resque-lock-timeout'
  s.version           = '0.2.0'
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = 'A Resque plugin adding locking, with optional timeout/deadlock handling to resque jobs.'
  s.homepage          = 'http://github.com/lantins/resque-lock-timeout'
  s.email             = 'luke@lividpenguin.com'
  s.authors           = ['Luke Antins', 'Ryan Carver', 'Chris Wanstrath']
  s.has_rdoc          = false

  s.files             = %w(README.md Rakefile LICENSE)
  s.files            += Dir.glob('lib/**/*')
  s.files            += Dir.glob('test/**/*')

  s.description       = <<desc
  A Resque plugin. Adds locking, with optional timeout/deadlock handling to
  resque jobs.

  Using a `lock_timeout` allows you to re-aquire the lock should your worker
  fail, crash, or is otherwise unable to relase the lock.
  
  i.e. Your server unexpectedly looses power. Very handy for jobs that are
  recurring or may be retried.
desc
end

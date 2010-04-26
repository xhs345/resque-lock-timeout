require 'rake/testtask'
require 'rake/rdoctask'

#
# Tests
#

task :default => :test

desc "Run tests"
Rake::TestTask.new(:test) do |task|
  task.test_files = FileList['test/*_test.rb']
  task.verbose = true
end

#
# Gems
#

begin
  require 'mg'
  MG.new("resque-lock.gemspec")

  desc "Build a gem."
  task :gem => :package

  # Ensure tests pass before pushing a gem.
  task :gemcutter => :test

  desc "Push a new version to Gemcutter and publish docs."
  task :publish => :gemcutter do
    sh "git push origin master --tags"
  end
rescue LoadError
  warn "mg not available."
  warn "Install it with: gem i mg"
end

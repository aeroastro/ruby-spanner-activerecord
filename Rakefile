ENV["RAILS_ENV"] = "test"

require "bundler/setup"
require "bundler/gem_tasks"

require "rubocop/rake_task"
RuboCop::RakeTask.new

require "rake/testtask"
Rake::TestTask.new :test do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

task default: :test

require "yard"
require "yard/rake/yardoc_task"
YARD::Rake::YardocTask.new do |y|
  # y.options << "--fail-on-warning"
end

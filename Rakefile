require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new :specs do |task|
  task.pattern = Dir['spec/**/*_spec.rb']
end

task :default => ['specs']

desc 'generate new uuid'
task :gen_uuid do
  require 'securerandom'
  puts SecureRandom.uuid
end

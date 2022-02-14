namespace :deploy do
  before :starting, :check_que_hooks do
    invoke 'que:add_default_hooks' if fetch(:que_default_hooks)
  end
end

namespace :que do
  task :add_default_hooks do
    after 'deploy:starting', 'que:quiet' if Rake::Task.task_defined?('que:quiet')
    after 'deploy:updated', 'que:stop'
    after 'deploy:published', 'que:start'
    after 'deploy:failed', 'que:restart'
  end
end

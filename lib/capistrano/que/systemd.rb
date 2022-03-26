module Capistrano
  class Que::Systemd < Capistrano::Plugin
    include Que::Helpers

    def set_defaults
      set_if_empty :que_service_unit_name, 'que'
      set_if_empty :que_service_unit_user, :user # :system
      set_if_empty :que_enable_lingering, true
      set_if_empty :que_lingering_user, nil
      set_if_empty :que_service_templates_path, 'config/deploy/templates'
      set_if_empty :que_queue_name, 'default'
    end

    def define_tasks
      eval_rakefile File.expand_path('../../tasks/systemd.rake', __FILE__)
    end
  end
end

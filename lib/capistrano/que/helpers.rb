module Capistrano
  module Que::Helpers
    
    def que_queue
      puts self.methods
      puts properties
      puts role
      puts server
      
      on roles(:que) do |server|
        server.properties.queue.to_s
      end
    end

    def que_require
      if fetch(:que_require)
        "--require #{fetch(:que_require)}"
      end
    end

    def que_config
      if fetch(:que_config)
        "--config #{fetch(:que_config)}"
      end
    end

    def que_concurrency
      if fetch(:que_concurrency)
        "--concurrency #{fetch(:que_concurrency)}"
      end
    end

    def que_queues
      Array(fetch(:que_queue)).map do |queue|
        "--queue #{queue}"
      end.join(' ')
    end

    def que_logfile
      fetch(:que_log)
    end

    def switch_user(role)
      su_user = que_user(role)
      if su_user == role.user
        yield
      else
        as su_user do
          yield
        end
      end
    end

    def que_user(role = nil)
      if role.nil?
        fetch(:que_user)
      else
        properties = role.properties
        properties.fetch(:que_user) || # local property for que only
          fetch(:que_user) ||
          properties.fetch(:run_as) || # global property across multiple capistrano gems
          role.user
      end
    end

    def expanded_bundle_path
      backend.capture(:echo, SSHKit.config.command_map[:bundle]).strip
    end

  end
end

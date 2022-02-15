# frozen_string_literal: true

git_plugin = self

namespace :que do
  namespace :systemd do
    desc 'Config Que systemd service'
    task :config do
      on roles(fetch(:que_role)) do |role|

        upload_compiled_template = lambda do |template_name, unit_filename|
          git_plugin.template_que template_name, "#{fetch(:tmp_dir)}/#{unit_filename}", role
          systemd_path = fetch(:que_systemd_conf_dir, git_plugin.fetch_systemd_unit_path)
          if fetch(:que_systemctl_user) == :system
            sudo "mv #{fetch(:tmp_dir)}/#{unit_filename} #{systemd_path}"
          else
            execute :mkdir, "-p", systemd_path
            execute :mv, "#{fetch(:tmp_dir)}/#{unit_filename}", "#{systemd_path}"
          end
        end

        upload_compiled_template.call("que.service", "#{fetch(:que_service_unit_name)}.service")

        # Reload systemd
        git_plugin.execute_systemd("daemon-reload")
      end
    end

    desc 'Generate service configuration locally'
    task :generate_config_locally do
      fake_role = Struct.new(:hostname)
      run_locally do
        File.write('que.service', git_plugin.compiled_template_que("que.service", fake_role.new("example.com")).string)
      end
    end

    desc 'Enable Que systemd service'
    task :enable do
      on roles(fetch(:que_role)) do
        git_plugin.execute_systemd("enable", fetch(:que_service_unit_name))

        if fetch(:que_systemctl_user) != :system && fetch(:que_enable_lingering)
          execute :loginctl, "enable-linger", fetch(:que_lingering_user)
        end
      end
    end

    desc 'Disable Que systemd service'
    task :disable do
      on roles(fetch(:que_role)) do
        git_plugin.execute_systemd("disable", fetch(:que_service_unit_name))
      end
    end
  end

  desc 'Start Que service via systemd'
  task :start do
    on roles(fetch(:que_role)) do
      git_plugin.execute_systemd("start", fetch(:que_service_unit_name))
    end
  end

  desc 'Stop Que service via systemd'
  task :stop do
    on roles(fetch(:que_role)) do
      git_plugin.execute_systemd("stop", fetch(:que_service_unit_name))
    end
  end

  desc 'Restarts or reloads Que service via systemd'
  task :smart_restart do
    if fetch(:que_phased_restart)
      invoke 'que:reload'
    else
      invoke 'que:restart'
    end
  end

  desc 'Restart Que service via systemd'
  task :restart do
    on roles(fetch(:que_role)) do
      git_plugin.execute_systemd("restart", fetch(:que_service_unit_name))
    end
  end

  desc 'Reload Que service via systemd'
  task :reload do
    on roles(fetch(:que_role)) do
      service_ok = if fetch(:que_systemctl_user) == :system
        execute("#{fetch(:que_systemctl_bin)} status #{fetch(:que_service_unit_name)} > /dev/null", raise_on_non_zero_exit: false)
      else
        execute("#{fetch(:que_systemctl_bin)} --user status #{fetch(:que_service_unit_name)} > /dev/null", raise_on_non_zero_exit: false)
      end
      cmd = 'reload'
      if !service_ok
        cmd = 'restart'
      end
      if fetch(:que_systemctl_user) == :system
        sudo "#{fetch(:que_systemctl_bin)} #{cmd} #{fetch(:que_service_unit_name)}"
      else
        execute "#{fetch(:que_systemctl_bin)}", "--user", cmd, fetch(:que_service_unit_name)
      end
    end
  end

  desc 'Get Que service status via systemd'
  task :status do
    on roles(fetch(:que_role)) do
      git_plugin.execute_systemd("status", fetch(:que_service_unit_name))
    end
  end
end

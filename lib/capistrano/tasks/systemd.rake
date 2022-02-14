git_plugin = self

namespace :que do

  standard_actions = {
    start: 'Start Que',
    stop: 'Stop Que (graceful shutdown within timeout, put unfinished tasks back to Redis)',
    status: 'Get Que Status'
  }
  standard_actions.each do |command, description|
    desc description
    task command do
      on roles fetch(:que_roles) do |role|
        git_plugin.switch_user(role) do
          git_plugin.systemctl_command(command)
        end
      end
    end
  end

  desc 'Restart Que (Quiet, Wait till workers finish or 30 seconds, Stop, Start)'
  task :restart do
    on roles fetch(:que_roles) do |role|
      git_plugin.switch_user(role) do
        git_plugin.quiet_que
        git_plugin.process_block do |process|
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          running = nil

          # get running workers
          while (running.nil? || running > 0) && git_plugin.duration(start_time) < 30 do
            command_args =
            if fetch(:que_service_unit_user) == :system
              [:sudo, 'systemd-cgls']
            else
              ['systemd-clgs', '--user']
            end
            # need to pipe through tr -cd... to strip out systemd colors or you
            # get log error messages for non UTF-8 characters.
            command_args.push(
              '-u', "#{git_plugin.que_service_unit_name(process: process)}.service",
              '|', 'tr -cd \'\11\12\15\40-\176\''
            )
            status = capture(*command_args, raise_on_non_zero_exit: false)
            status_match = status.match(/\[(?<running>\d+) of (?<total>\d+) busy\]/)
            break unless status_match

            running = status_match[:running]&.to_i

            colors = SSHKit::Color.new($stdout)
            if running.zero?
              info colors.colorize("✔ Process ##{process}: No running workers. Shutting down for restart!", :green)
            else
              info colors.colorize("⧗ Process ##{process}: Waiting for #{running} workers.", :yellow)
              sleep(1)
            end
          end

          git_plugin.systemctl_command(:stop, process: process)
          git_plugin.systemctl_command(:start, process: process)
        end
      end
    end
  end

  desc 'Quiet Que (stop fetching new tasks from Redis)'
  task :quiet do
    on roles fetch(:que_roles) do |role|
      git_plugin.switch_user(role) do
        git_plugin.quiet_que
      end
    end
  end

  desc 'Install systemd que service'
  task :install do
    on roles fetch(:que_roles) do |role|
      git_plugin.switch_user(role) do
        git_plugin.create_systemd_template
        if git_plugin.config_per_process?
          git_plugin.process_block do |process|
            git_plugin.create_systemd_config_symlink(process)
          end
        end
        git_plugin.systemctl_command(:enable)

        if fetch(:que_service_unit_user) != :system && fetch(:que_enable_lingering)
          execute :loginctl, "enable-linger", fetch(:que_lingering_user)
        end
      end
    end
  end

  desc 'Uninstall systemd que service'
  task :uninstall do
    on roles fetch(:que_roles) do |role|
      git_plugin.switch_user(role) do
        git_plugin.systemctl_command(:stop)
        git_plugin.systemctl_command(:disable)
        if git_plugin.config_per_process?
          git_plugin.process_block do |process|
            git_plugin.delete_systemd_config_symlink(process)
          end
        end
        execute :sudo, :rm, '-f', File.join(
          fetch(:service_unit_path, git_plugin.fetch_systemd_unit_path),
          git_plugin.que_service_file_name
        )
      end
    end
  end

  desc 'Generate service_locally'
  task :generate_service_locally do
    run_locally do
      File.write('que', git_plugin.compiled_template)
    end
  end

  def fetch_systemd_unit_path
    if fetch(:que_service_unit_user) == :system
      # if the path is not standard `set :service_unit_path`
      "/etc/systemd/system/"
    else
      home_dir = backend.capture :pwd
      File.join(home_dir, ".config", "systemd", "user")
    end
  end

  def compiled_template
    local_template_directory = fetch(:que_service_templates_path)
    search_paths = [
      File.join(local_template_directory, "#{fetch(:que_service_unit_name)}.service.capistrano.erb"),
      File.join(local_template_directory, 'que.service.capistrano.erb'),
      File.expand_path(
          File.join(*%w[.. .. .. generators capistrano que systemd templates que.service.capistrano.erb]),
          __FILE__
      ),
    ]
    template_path = search_paths.detect { |path| File.file?(path) }
    template = File.read(template_path)
    ERB.new(template).result(binding)
  end

  def create_systemd_template
    ctemplate = compiled_template
    systemd_path = fetch(:service_unit_path, fetch_systemd_unit_path)
    systemd_file_name = File.join(systemd_path, que_service_file_name)

    if fetch(:que_service_unit_user) == :user
      backend.execute :mkdir, "-p", systemd_path
    end

    temp_file_name = File.join('/tmp', que_service_file_name)
    backend.upload!(StringIO.new(ctemplate), temp_file_name)
    if fetch(:que_service_unit_user) == :system
      backend.execute :sudo, :mv, temp_file_name, systemd_file_name
      backend.execute :sudo, :systemctl, "daemon-reload"
    else
      backend.execute :mv, temp_file_name, systemd_file_name
      backend.execute :systemctl, "--user", "daemon-reload"
    end
  end

  def create_systemd_config_symlink(process)
    config = fetch(:que_config)
    return unless config

    process_config = config[process - 1]
    if process_config.nil?
      backend.error(
        "No configuration for Process ##{process} found. "\
        'Please make sure you have 1 item in :que_config for each process.'
      )
      exit 1
    end

    base_path = fetch(:deploy_to)
    config_link_base_path = File.join(base_path, 'shared', 'que_systemd')
    config_link_path = File.join(
      config_link_base_path, que_systemd_config_name(process)
    )
    process_config_path = File.join(base_path, 'current', process_config)

    backend.execute :mkdir, '-p', config_link_base_path
    backend.execute :ln, '-sf', process_config_path, config_link_path
  end

  def delete_systemd_config_symlink(process)
    config_link_path = File.join(
      fetch(:deploy_to),  'shared', 'que_systemd',
      que_systemd_config_name(process)
    )
    backend.execute :rm, config_link_path, raise_on_non_zero_exit: false
  end

  def systemctl_command(*args, process: nil)
    execute_array =
      if fetch(:que_service_unit_user) == :system
        [:sudo, :systemctl]
      else
        [:systemctl, '--user']
      end

    if process
      execute_array.push(
        *args, que_service_unit_name(process: process)
        ).flatten
      backend.execute(*execute_array, raise_on_non_zero_exit: false)
    else
      execute_array.push(*args, que_service_unit_name).flatten
      backend.execute(*execute_array, raise_on_non_zero_exit: false)
    end
  end

  def quiet_que
    systemctl_command(:kill, '-s', :TSTP)
  end

  def switch_user(role)
    su_user = que_user
    if su_user != role.user
      yield
    else
      backend.as su_user do
        yield
      end
    end
  end

  def que_user
    fetch(:que_user, fetch(:run_as))
  end

  def que_config
    config = fetch(:que_config)
    return unless config

    if config_per_process?
      config = File.join(
        fetch(:deploy_to), 'shared', 'que_systemd',
        que_systemd_config_name
      )
      "--config #{config}"
    else
      "--config #{config}"
    end
  end

  def que_concurrency
    if fetch(:que_concurrency)
      "--concurrency #{fetch(:que_concurrency)}"
    end
  end

  def que_processes
    fetch(:que_processes, 1)
  end

  def que_queues
    Array(fetch(:que_queue)).map do |queue|
      "--queue #{queue}"
    end.join(' ')
  end

  def que_service_file_name
    "#{fetch(:que_service_unit_name)}@.service"
  end

  def que_service_unit_name(process: nil)
    if process
      "#{fetch(:que_service_unit_name)}@#{process}"
    else
      "#{fetch(:que_service_unit_name)}@{1..#{que_processes}}"
    end
  end

  # process = 1 | que_systemd_1.yaml
  # process = nil | que_systemd_%i.yaml
  def que_systemd_config_name(process = nil)
    file_name = 'que_systemd_'
    file_name << (process&.to_s || '%i')
    "#{file_name}.yaml"
  end

  def config_per_process?
    fetch(:que_config).is_a?(Array)
  end

  def process_block
    (1..que_processes).each do |process|
      yield(process)
    end
  end

  def duration(start_time)
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
  end

end

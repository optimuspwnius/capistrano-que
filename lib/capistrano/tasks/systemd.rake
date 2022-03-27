git_plugin = self

namespace :que do

  standard_actions = {
    start: 'Start Que',
    stop: 'Stop Que',
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
    puts "fetch(:queue) -> #{fetch(:queue)}"
    
    on roles(:que), in: :sequence do |role|
      puts "fetch(:queue) in roles -> #{fetch(:queue)}"
      git_plugin.set :queue, role.properties.queue
      git_plugin.switch_user(role) do
        puts "fetch(:queue) in switch user -> #{fetch(:queue)}"
        #puts "task: #{role.properties.queue}"
        
        puts "fetch(:queue) in switch user after setting -> #{fetch(:queue)}"
        git_plugin.create_systemd_template
        git_plugin.systemctl_command(:enable)

        if fetch(:que_service_unit_user) != :system and fetch(:que_enable_lingering)
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
        execute :rm, '-f', File.join(
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
    home_dir = backend.capture :pwd
    File.join(home_dir, ".config", "systemd", "user")
  end

  def compiled_template
    puts "fetch(:queue) in compiled_template -> #{fetch(:queue)}"
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
    puts ERB.new(template).result(binding)
    ERB.new(template).result(binding)
  end

  def create_systemd_template
    puts "fetch(:queue) in create_systemd_template -> #{fetch(:queue)}"
    ctemplate = compiled_template
    systemd_path = fetch(:service_unit_path, fetch_systemd_unit_path)
    systemd_file_name = File.join(systemd_path, que_service_file_name)

    backend.execute :mkdir, "-p", systemd_path

    temp_file_name = File.join('/tmp', "#{que_service_file_name}_#{SecureRandom.hex(10)}")
    backend.upload!(StringIO.new(ctemplate), temp_file_name)

    backend.execute :mv, temp_file_name, systemd_file_name
    backend.execute :systemctl, "--user", "daemon-reload"
  end

  def systemctl_command(*args, process: nil)
    execute_array = [:systemctl, '--user']
    if process
      execute_array.push(
        *args, fetch(:que_service_unit_name)
        ).flatten
      backend.execute(*execute_array, raise_on_non_zero_exit: false)
    else
      execute_array.push(*args, fetch(:que_service_unit_name)).flatten
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

  def que_processes
    fetch(:que_processes, 1)
  end

  def que_service_file_name
    "#{fetch(:que_service_unit_name)}.service"
  end

  def process_block
    (1..que_processes).each do |process|
      yield(process)
    end
  end

end

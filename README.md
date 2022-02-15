# Capistrano::Que

Que integration for Capistrano

## Installation

    gem 'capistrano-que', group: :development

And then execute:

    $ bundle

## Usage
```ruby
    # Capfile

    require 'capistrano/que'
    install_plugin Capistrano::Que
    install_plugin Capistrano::Que::Systemd
```

Ensure your server has a .rbenv-vars with RAILS_ENV=production otherwise the service will fail to start

Configurable options - Please ensure you check your version's branch for the available settings - shown here with defaults:

```ruby
:que_roles => :app
:que_default_hooks => true
:que_pid => File.join(shared_path, 'tmp', 'pids', 'que.pid') # ensure this path exists in production before deploying.
:que_env => fetch(:rack_env, fetch(:rails_env, fetch(:stage)))
:que_log => File.join(shared_path, 'log', 'que.log')
:que_queue => %w(default)

# que systemd options
:que_service_unit_name => 'que'
:que_service_unit_user => :user # :system
:que_enable_lingering => true
:que_lingering_user => nil
:que_user => nil #user to run que as
```
See `capistrano/que/helpers.rb` for other undocumented configuration settings.

## Bundler

If you'd like to prepend `bundle exec` to your que calls, modify the SSHKit command maps
in your deploy.rb file:
```ruby
SSHKit.config.command_map[:que] = "bundle exec que"
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

require 'capistrano/bundler'
require "capistrano/plugin"

module Capistrano
  class Que < Capistrano::Plugin
    def define_tasks
      eval_rakefile File.expand_path('../tasks/que.rake', __FILE__)
    end

    def set_defaults
      set_if_empty :que_default_hooks, true

      set_if_empty :que_env, -> { fetch(:rack_env, fetch(:rails_env, fetch(:rake_env, fetch(:stage)))) }
      set_if_empty :que_roles, fetch(:que_role, :app)
      set_if_empty :que_log, -> { File.join(shared_path, 'log', 'que.log') }
      set_if_empty :que_error_log, -> { File.join(shared_path, 'log', 'que.error.log') }
      # Rbenv, Chruby, and RVM integration
      append :rbenv_map_bins, 'que', 'quectl'
      append :rvm_map_bins, 'que', 'quectl'
      append :chruby_map_bins, 'que', 'quectl'
      # Bundler integration
      append :bundle_bins, 'que', 'quectl'
    end

  end
end

require_relative 'que/helpers'
require_relative 'que/systemd'

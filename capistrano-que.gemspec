# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'capistrano/que/version'

Gem::Specification.new do |spec|
  spec.name = 'capistrano-que'
  spec.version = Capistrano::QueVERSION
  spec.authors = ['Tayden Miller']
  spec.email = ['tayden007@hotmail.com']
  spec.summary = %q{Que integration for Capistrano}
  spec.description = %q{Que integration for Capistrano}
  spec.homepage = 'https://github.com/optimuspwnius/capistrano-que'
  spec.license = 'LGPL-3.0'

  spec.required_ruby_version     = '>= 2.0.0'
  spec.files = `git ls-files`.split($/)
  spec.require_paths = ['lib']

  spec.add_dependency 'capistrano', '>= 3.9.0'
  spec.add_dependency 'capistrano-bundler'
  spec.add_dependency 'que'
end

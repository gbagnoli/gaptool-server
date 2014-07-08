# encoding: utf-8
require 'sinatra'
require 'sinatra/can'
require 'json'
require 'yaml'
require 'erb'
require 'aws-sdk'
require 'openssl'
require 'ohm'
require 'net/ssh'
require 'peach'
require_relative 'models/init'

class GaptoolServer < Sinatra::Application
  disable :sessions
  enable  :dump_errors

  user do
    usern = env['HTTP_X_GAPTOOL_USER']
    key = env['HTTP_X_GAPTOOL_KEY']
    user = User.login(usern, key)
    unless user
      error 401
    end
    user
  end

  ability do |usr|
    can :manage, :all if usr.role.name == 'admin'
    can :read, :all
  end

  error do
    {:result => 'error', :message => env['sinatra.error']}.to_json
  end

  not_found do
    {:result => 'error', :message => "Not Found."}.to_json
  end
end

require_relative 'helpers/init'
require_relative 'routes/init'

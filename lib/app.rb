# encoding: utf-8
require 'sinatra'
require 'sinatra/can'
require "sinatra/json"
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
  helpers Sinatra::JSON
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
    can :manage, :all if usr.role == 'admin'
    can :read, :all
  end

  error 400 do
    json({:result => 'error', :message => "Invalid request."})
  end

  error 401 do
    json({:result => 'error', :message => 'Unauthorized.'})
  end

  error 500 do
    json({:result => 'error', :message => 'Internal Error.'})
  end

  error 409 do
    json({:result => 'error', :message => 'Conflict.'})
  end

  not_found do
    json({:result => 'error', :message => "Not Found."})
  end
end

require_relative 'helpers/init'
require_relative 'routes/init'

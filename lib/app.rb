# encoding: utf-8
require 'sinatra'
require 'json'
require 'yaml'
require 'erb'
require 'aws-sdk'
require 'openssl'
require 'net/ssh'
require 'peach'

class GaptoolServer < Sinatra::Application
  disable :sessions
  enable :show_exceptions
  enable :raise_errors
  enable :dump_errors

  before do
    error 401 unless $redis.hget('users', env['HTTP_X_GAPTOOL_USER']) == env['HTTP_X_GAPTOOL_KEY']
    error 401 unless env['HTTP_X_GAPTOOL_USER'] && env['HTTP_X_GAPTOOL_KEY']
  end

  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
  end
end

require_relative 'helpers/init'
require_relative 'models/init'
require_relative 'routes/init'

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
  enable  :dump_errors

  error do
    {:result => 'error', :message => env['sinatra.error']}.to_json
  end

  not_found do
      {}
  end

  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
  end
end

require_relative 'helpers/init'
require_relative 'routes/init'

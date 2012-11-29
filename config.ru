require 'sinatra/base'
require 'sinatra'
require 'json'
require 'redis'
require 'yaml'
require 'erb'
require 'aws-sdk'
require 'openssl'
require 'net/ssh'

require 'lib/gaptool-server.rb'

run GaptoolServer

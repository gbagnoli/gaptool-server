#!/usr/bin/env ruby

require 'sinatra/base'
require 'sinatra'
require 'json'
require 'redis'
require 'yaml'
require 'erb'
require 'aws-sdk'
require 'openssl'
require 'net/ssh'

$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), "lib")))

require 'gaptool-server/app.rb'

run GaptoolServer

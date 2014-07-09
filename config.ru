#!/usr/bin/env ruby

require 'redis'

ENV['GT_REDIS_HOST'] = 'localhost' unless ENV['GT_REDIS_HOST']
ENV['GT_REDIS_PORT'] = '6379' unless ENV['GT_REDIS_PORT']
ENV['GT_REDIS_DB'] = '0' unless ENV['GT_REDIS_PORT']
ENV['GT_REDIS_PASS'] = nil unless ENV['GT_REDIS_PASS']

libpath = File.expand_path(File.join(File.dirname(__FILE__), "lib"))
$:.unshift(libpath)
require "#{libpath}/app.rb"

instance = GaptoolServer.new
run instance

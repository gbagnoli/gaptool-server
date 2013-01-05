#!/usr/bin/env ruby

require 'redis'

ENV['REDIS_HOST'] = 'localhost' unless ENV['REDIS_HOST']
ENV['REDIS_PORT'] = '6379' unless ENV['REDIS_PORT']
ENV['REDIS_PASS'] = nil unless ENV['REDIS_PASS']
$redis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_PORT'], :password => ENV['REDIS_PASS'])

libpath = File.expand_path(File.join(File.dirname(__FILE__), "lib"))

$:.unshift(libpath)

require "#{libpath}/app.rb"
#Dir["#{ENV['HOME']}/.gaptool-server-plugins/*.rb"].each {|file| require file }
#Dir["#{libpath}/plugins/*.rb"].each {|file| require file }

instance = GaptoolServer.new
#$redis.smembers("plugins").each do |plugin|
##  puts "Loading Plugin #{plugin}"
#  instance.extend(Object.instance_eval{remove_const(plugin)})
#end

run instance

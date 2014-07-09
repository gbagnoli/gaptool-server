require 'ohm'

REDIS_HOST = ENV['GT_REDIS_HOST'] || "localhost"
REDIS_PORT = ENV['GT_REDIS_PORT'] || "6379"
REDIS_DB = ENV['GT_REDIS_DB'] || '0'
REDIS_PASS = ENV['GT_REDIS_PASS'] || nil

pass = REDIS_PASS ? ":#{REDIS_PASS}@" : ""
Ohm.redis = Redic.new("redis://#{pass}#{REDIS_HOST}:#{REDIS_PORT}/#{REDIS_DB}")

require_relative 'user'

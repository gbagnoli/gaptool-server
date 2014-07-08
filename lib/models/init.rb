require 'ohm'

REDIS_HOST = ENV['GT_REDIS_HOST'] || "127.0.0.1"
REDIS_PORT = ENV['GT_REDIS_PORT'] || "6379"
REDIS_DB = ENV['GT_REDIS_DB'] || '0'

Ohm.redis = Redic.new("redis://#{REDIS_HOST}:#{REDIS_PORT}/#{REDIS_DB}")

require_relative 'user'

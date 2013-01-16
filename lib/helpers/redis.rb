# encoding: utf-8
module RedisHelpers
  def remotellen(lists)
    @remote_redis = Redis.new(
      :host => $redis.hget('config', 'remoteredis:host'),
      :port => $redis.hget('config', 'remoteredis:port'),
      :password => nil || $redis.hget('config', 'remoteredis:password')
    )
    result = Hash.new
    lists.each do |list|
      result.merge!(list => @remote_redis.llen(list))
    end
    return result
  end

  def remotelpush(list, value)
    @remote_redis = Redis.new(
      :host => $redis.hget('config', 'remoteredis:host'),
      :port => 6379 || $redis.hget('config', 'remoteredis:port'),
      :password => nil || $redis.hget('config', 'remoteredis:password')
    )
    begin
      @remote_redis.lpush(list, value)
      return { success => "true" }
    rescue
      return { success => "false" }
    end
  end
end

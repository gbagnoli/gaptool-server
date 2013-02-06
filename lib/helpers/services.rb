# encoding: utf-8
module ServiceHelpers
  def svcapi_getkey(service)
    $redis.brpoplpush("apikey:available:#{service}", "apikey:inuse:#{service}", 120)
  end
  def svcapi_releasekey(service, key)
    $redis.lrem("apikey:inuse:#{service}", 1, key)
    $redis.rpush("apikey:available:#{service}", key)
  end
  def svcapi_showkeys(service)
    unless service == :all
      @inuse = $redis.lrange("apikey:inuse:#{service}", 0, -1)
      @available = $redis.lrange("apikey:available:#{service}", 0, -1)
      return { :inuse => @inuse, :available => @available }
    else
      @all = Hash.new
      $redis.keys('apikey:inuse:*').each do |service|
        @all[service.gsub('apikey:inuse:', '')][:inuse] = $redis.lrange("apikey:inuse:#{service}", 0, -1)
      end
      $redis.keys('apikey:available:*').each do |service|
        @all[service][:available] = $redis.lrange("apikey:available:#{service}", 0, -1)
      end
      return @all
    end
  end
  def svcapi_deletekey(service, key)
    begin
      $redis.lrem("apikey:inuse:#{service}", 1, key)
      $redis.lrem("apikey:available:#{service}", 1, key)
    rescue
    end
  end
  def svcapi_putkey(service, key)
    $redis.lpush("apikey:available:#{service}", key)
  end
end

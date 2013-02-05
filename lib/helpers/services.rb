# encoding: utf-8
module ServiceHelpers
  def getkey(service)
    $redis.brpoplpush("apikey:available:#{service}", "apikey:inuse:#{service}", 120)
  end
  def releasekey(service, key)
    $redis.lrem("apikey:inuse:#{service}", 1, key)
    $redis.rpush("apikey:available:#{service}", key)
  end
  def showkeys(service)
    @inuse = $redis.lrange("apikey:inuse:#{service}", 0, -1)
    @available = $redis.lrange("apikey:available:#{service}", 0, -1)
    return { :inuse => @inuse, :available => @available }
  end
end

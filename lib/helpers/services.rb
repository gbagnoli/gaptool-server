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
      $redis.keys('apikey:*').each do |service|
        if service =~ /:available:/
          begin
            @all[service.gsub('apikey:available:', '')][:available] = $redis.lrange(service, 0, -1)
          rescue
            @all[service.gsub('apikey:available:', '')] = Hash.new
            @all[service.gsub('apikey:available:', '')][:available] = $redis.lrange(service, 0, -1)
          end
        elsif service =~ /:inuse:/
          begin
            @all[service.gsub('apikey:inuse:', '')][:inuse] = $redis.lrange(service, 0, -1)
          rescue
            @all[service.gsub('apikey:inuse:', '')] = Hash.new
            @all[service.gsub('apikey:inuse:', '')][:inuse] = $redis.lrange(service, 0, -1)
          end
        end
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

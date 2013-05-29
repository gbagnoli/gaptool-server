module RehashHelpers
  def rehash()
    @layout = {}
    @roles = []
    $redis.keys('app:*').each do |app|
      role = $redis.hget(app,'role')
      unless role == 'nil'
        @roles << role
      end
    end
    $redis.keys('host:*').each do |key|
      @roles << key.gsub('host:','').gsub(/:.*:i-.*/,'')
    end
    @roles.uniq!
    @roles.each do |role|
      apps = []
      $redis.keys('app:*').each do |app|
        if $redis.hget(app,'role') == role
          apps << app.gsub('app:','')
        end
      end
      @layout[role] = apps
    end

    $redis.keys("host:*").each do |rediskey|
      $redis.del rediskey
    end

    $redis.keys("instance:*").each do |rediskey|
      $redis.del rediskey
    end

    @zones = $redis.hgetall('amis').keys
    @zones.each do |zone|
      @ec2 = AWS::EC2.new(:access_key_id => $redis.hget('config', 'aws_id'), :secret_access_key => $redis.hget('config', 'aws_secret'), :ec2_endpoint => "ec2.#{zone}.amazonaws.com")
      @instances = []
      @ec2.instances.each do |instance|
        if instance.tags['gaptool'] == 'yes'
          @instances << instance
        end
      end
      @instances.each do |instance|
        @name = instance.tags['Name'].split('-')
        @rediskey = "host:#{@name[0]}:#{@name[1]}:i-#{@name.last}"
        @host = {
          "zone"=> instance.availability_zone,
          "itype"=> instance.instance_type,
          "role"=> @name.first,
          "environment"=> @name[1],
          "secret"=>"NA",
          "capacity"=>"6",
          "hostname"=> instance.public_dns_name,
          "apps" => @layout[@name[0]].to_s,
          "instance"=> instance.instance_id
        }
        @host.keys.each do |key|
          $redis.hset(@rediskey, key, @host[key])
        end
      end
    end
    return "complete"
  end
end

# encoding: utf-8
module GaptoolBaseHelpers
  def hash2redis( key, hash )
    hash.keys.each do |hkey|
      $redis.hset key, hkey, hash[hkey]
    end
  end

  def putkey( host )
    @key = OpenSSL::PKey::RSA.new 2048
    @pubkey = "#{@key.ssh_type} #{[@key.to_blob].pack('m0')} GAPTOOL_GENERATED_KEY"
    ENV['SSH_AUTH_SOCK'] = ''
    Net::SSH.start(host, 'admin', :key_data => [$redis.hget('config', 'gaptoolkey')], :config => false, :keys_only => true, :paranoid => false) do |ssh|
      ssh.exec! "grep -v GAPTOOL_GENERATED_KEY ~/.ssh/authorized_keys > /tmp/pubkeys"
      ssh.exec! "cat /tmp/pubkeys > ~/.ssh/authorized_keys"
      ssh.exec! "rm /tmp/pubkeys"
      ssh.exec! "echo #{@pubkey} >> ~/.ssh/authorized_keys"
    end
    return @key.to_pem
  end

  def gt_securitygroup(role, environment, zone)
    AWS.config(:access_key_id => $redis.hget('config', 'aws_id'), :secret_access_key => $redis.hget('config', 'aws_secret'), :ec2_endpoint => "ec2.#{zone.chop}.amazonaws.com")
    @ec2 = AWS::EC2.new
    groupname = "#{role}-#{environment}"
    default_list = [ 22 ]
    @ec2.security_groups.each do |group|
      if group.name == "#{role}-#{environment}"
        return group.id
      end
    end
    internet = ['0.0.0.0/0']
    sg = @ec2.security_groups.create("#{role}-#{environment}")
    sg.authorize_ingress :tcp, 22, *internet
    return sg.id
  end

  def runservice(host, role, environment, service, keys, state)
    ENV['SSH_AUTH_SOCK'] = ''
    Net::SSH.start(host, 'admin', :key_data => [$redis.hget('config', 'gaptoolkey')], :config => false, :keys_only => true, :paranoid => false) do |ssh|
      if state == 'start'
        ssh.exec! "echo '#{keys.to_yaml}' > /tmp/apikeys-#{service}.yml"
        ssh.exec! "sudo restart #{service} || sudo start #{service} || exit 0"
        $redis.lpush("running", "{:hostname => '#{host}', :role => '#{role}', :environment => '#{environment}', :service => '#{service}'}")
      elsif state == 'stop'
        ssh.exec! "rm /tmp/apikeys-#{service}.yml"
        ssh.exec! "sudo stop #{service} || exit 0"
        $redis.lrem("running", -1, "{:hostname => '#{host}', :role => '#{role}', :environment => '#{environment}', service => '#{service}'}")
      end
    end
  end

  def balanceservices(role, environment)
    @runable = Array.new
    @available = Array.new
    @totalcap = 0
    @volume = 0
    $redis.keys("host:#{role}:#{environment}:*").each do |host|
      @available << {
        :hostname => $redis.hget(host, 'hostname'),
        :instance => $redis.hget(host, 'instance'),
        :capacity => $redis.hget(host, 'capacity').to_i,
      }
      @totalcap = @totalcap + $redis.hget(host, 'capacity').to_i
    end
    $redis.keys("service:#{role}:#{environment}:*").each do |service|
      unless service =~ /:count/
        if $redis.hget(service, 'run').to_i == 1
          @runable << {
            :name => $redis.hget(service, 'name'),
            :keys => eval($redis.hget(service, 'keys')),
            :weight => $redis.hget(service, 'weight').to_i
          }
        end
      end
    end
    @volume = 0
    @runable.each do |service|
      @volume += service[:weight]
    end
    if @totalcap < @volume
      return { :error => true, :message => "This would overcommit, remove some resources or add nodes", :totalcap => @totalcap, :volume => @volume }
    else
      @runable.sort! { |x, y| x[:weight] <=> y[:weight] }
      @available.sort! { |x, y| x[:capacity] <=> y[:capacity] }
      @runlist = Array.new
      @svctab = Hash.new
      @runable.each do |event|
        @svctab[event[:name]] = Array.new
      end
      @exitrunable = 0
      while @runable != []
        break if @exitrunable == 1
        @available.each do |host|
          break if @runable.last.nil?
          @exitrunable = 1 if @svctab[@runable.last[:name]].include? host[:hostname]
          break if @svctab[@runable.last[:name]].include? host[:hostname]
          if host[:capacity] >= @runable.last[:weight]
            host[:capacity] = host[:capacity] - @runable.last[:weight]
            @svctab[@runable.last[:name]] << host[:hostname]
            @runlist << { :host => host, :service => @runable.pop }
          end
        end
      end
      return @runlist
    end
  end

  def servicestopall(role, environment)
    $redis.lrange('running', 0, -1).peach do |service|
      line = eval(service)
      if line[:role] == role && line[:environment] == environment
        runservice(line[:hostname], role, environment, line[:service], nil, 'stop')
      end
    end
  end

  def hostsgen(zone)
    AWS.config(:access_key_id => $redis.hget('config', 'aws_id'), :secret_access_key => $redis.hget('config', 'aws_secret'), :ec2_endpoint => "ec2.#{zone}.amazonaws.com")
    @ec2 = AWS::EC2.new
    hosts = Hash.new
    $redis.keys("host:*").each do |host|
      $redis.hset(host, 'hostname', @ec2.instances[$redis.hget(host, 'instance')].dns_name)
      hosts.merge!(host.gsub(/host:/, '').gsub(/:/,'-') => Resolv.getaddress($redis.hget(host, 'hostname')))
      if $redis.hget(host, 'alias')
        hosts.merge!($redis.hget(host, 'alias') => Resolv.getaddress($redis.hget(host, 'hostname')))
      end
    end

    hostsfile = "# DO NOT EDIT, GENERATED BY GAPTOOL\n127.0.0.1 localhost\n::1 localhost\n"
    hosts.keys.each do |key|
      hostsfile += "#{hosts[key]} #{key} # PLACED BY GT\n"
    end
#    $redis.keys("host:*").peach do |host|
#      ENV['SSH_AUTH_SOCK'] = ''
#      Net::SSH.start($redis.hget(host, 'hostname'), 'admin', :key_data => [$redis.hget('config', 'gaptoolkey')], :config => false, :keys_only => true, :paranoid => false) do |ssh|
#        ssh.exec! "echo \"127.0.0.1 #{currenthost}\n\" \"#{hostsfile}\" > /etc/hosts.generated"
#      end
#    end
    return hosts
  end

  def getservices()
    services = Array.new
    $redis.keys('service:*').each do |service|
      unless service =~ /:count/
        line = $redis.hgetall(service)
        line['keys'] = eval(line['keys'])
        services << line
      end
    end
    return services
  end

end

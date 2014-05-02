# encoding: utf-8
class GaptoolServer < Sinatra::Application

  get '/' do
    raise "You must be lost. Read the instructions."
  end

  post '/redishash' do
    data = JSON.parse request.body.read
    redishash(data).to_json
  end

  get '/servicebalance/:role/:environment' do
    runlist = balanceservices(params[:role], params[:environment])
    unless runlist.kind_of? Hash
      servicestopall(params[:role], params[:environment])
      runlist.peach do |event|
        runservice(event[:host][:hostname], params[:role], params[:environment], event[:service][:name], event[:service][:keys], 'start')
      end
    end
    runlist.to_json
  end

  post '/regenhosts' do
    data = JSON.parse request.body.read
    hostsgen(data['zone'])
    hosts.to_json
  end

  post '/init' do
    data = JSON.parse request.body.read
    AWS.config(:access_key_id => $redis.hget('config', 'aws_id'), :secret_access_key => $redis.hget('config', 'aws_secret'), :ec2_endpoint => "ec2.#{data['zone'].chop}.amazonaws.com")
    @ec2 = AWS::EC2.new
    # create shared secret to reference in /register
    @secret = (0...8).map{65.+(rand(26)).chr}.join
    data.merge!("secret" => @secret)
    sgid = gt_securitygroup(data['role'], data['environment'], data['zone'])
    image_id = $redis.hget("amis:#{data['role']}", data['zone'].chop) || $redis.hget("amis", data['zone'].chop)
    if data['mirror']
      instance = @ec2.instances.create(
        :image_id => image_id,
        :availability_zone => data['zone'],
        :instance_type => data['itype'],
        :key_name => "gaptool",
        :security_group_ids => sgid,
        :user_data => "#!/bin/bash\ncurl --silent -H 'X-GAPTOOL-USER: #{env['HTTP_X_GAPTOOL_USER']}' -H 'X-GAPTOOL-KEY: #{env['HTTP_X_GAPTOOL_KEY']}' #{$redis.hget('config', 'url')}/register -X PUT --data '#{data.to_json}' | bash",
        :block_device_mappings => {
          "/dev/sdf" => {
            :volume_size => data['mirror'].to_i,
            :delete_on_termination => false
          },
          "/dev/sdg" => {
            :volume_size => data['mirror'].to_i,
            :delete_on_termination => false
          }
        }
      )
    else
      instance = @ec2.instances.create(
        :image_id => image_id,
        :availability_zone => data['zone'],
        :instance_type => data['itype'],
        :key_name => "gaptool",
        :security_group_ids => sgid,
        :user_data => "#!/bin/bash\ncurl --silent -H 'X-GAPTOOL-USER: #{env['HTTP_X_GAPTOOL_USER']}' -H 'X-GAPTOOL-KEY: #{env['HTTP_X_GAPTOOL_KEY']}' #{$redis.hget('config', 'url')}/register -X PUT --data '#{data.to_json}' | bash"
      )
    end
    # Add host tag
    instance.add_tag('Name', :value => "#{data['role']}-#{data['environment']}-#{instance.id}")
    instance.add_tag('gaptool', :value => "yes")
    # Create temporary redis entry for /register to pull the instance id
    $redis.set("instance:#{data['role']}:#{data['environment']}:#{@secret}", instance.id)
    "{\"instance\":\"#{instance.id}\"}"
  end

  post '/terminate' do
    data = JSON.parse request.body.read
    AWS.config(:access_key_id => $redis.hget('config', 'aws_id'), :secret_access_key => $redis.hget('config', 'aws_secret'), :ec2_endpoint => "ec2.#{data['zone']}.amazonaws.com")
    @ec2 = AWS::EC2.new
    @instance = @ec2.instances[data['id']]
    res = @instance.terminate
    res = $redis.del($redis.keys("*#{data['id']}"))
    out = {data['id'] => {'status'=> 'terminated'}}
    out.to_json
  end

  put '/register' do
    data = JSON.parse request.body.read
    AWS.config(:access_key_id => $redis.hget('config', 'aws_id'), :secret_access_key => $redis.hget('config', 'aws_secret'), :ec2_endpoint => "ec2.#{data['zone'].chop}.amazonaws.com")
    @ec2 = AWS::EC2.new
    @instance = @ec2.instances[$redis.get("instance:#{data['role']}:#{data['environment']}:#{data['secret']}")]
    hostname = @instance.dns_name
    $redis.del("instance:#{data['role']}:#{data['environment']}:#{data['secret']}")
    @apps = []
    $redis.keys("app:*").each do |app|
      if $redis.hget(app, 'role') == data['role']
        @apps << app.gsub('app:', '')
      end
    end
    data.merge!("capacity" => $redis.hget('capacity', data['itype']))
    data.merge!("hostname" => hostname)
    data.merge!("apps" => @apps.to_json)
    data.merge!("instance" => @instance.id)
    hash2redis("host:#{data['role']}:#{data['environment']}:#{@instance.id}", data)
    @json = {
      'hostname' => hostname,
      'recipe' => 'init',
      'number' => @instance.id,
      'run_list' => ['recipe[init]'],
      'role' => data['role'],
      'environment' => data['environment'],
      'chefrepo' => $redis.hget('config', 'chefrepo'),
      'chefbranch' => $redis.hget('config', 'chefbranch'),
      'identity' => $redis.hget('config','initkey'),
      'appuser' => $redis.hget('config','appuser'),
      'apps' => @apps
    }.to_json
    erb :init
  end

  get '/hosts' do
    out = []
    $redis.keys("host:*").each do |host|
      out << $redis.hgetall(host)
    end
    out.to_json
  end

  get '/apps' do
    out = {}
    $redis.keys("app:*").each do |app|
      out.merge!(app => $redis.hgetall(app))
    end
    out.to_json
  end

  get '/hosts/:role' do
    out = []
    $redis.keys("host:#{params[:role]}:*").each do |host|
      out << $redis.hgetall(host)
    end
    out.to_json
  end

  get '/instance/:id' do
    $redis.hgetall($redis.keys("host:*:*:#{params[:id]}").first).to_json
  end

  get '/hosts/:role/:environment' do
    out = []
    unless params[:role] == "ALL"
      $redis.keys("host:#{params[:role]}:#{params[:environment]}*").each do |host|
        out << $redis.hgetall(host)
      end
    else
      $redis.keys("host:*:#{params[:environment]}:*").each do |host|
        out << $redis.hgetall(host)
      end
    end
    out.to_json
  end

  get '/host/:role/:environment/:instance' do
    $redis.hgetall("host:#{params[:role]}:#{params[:environment]}:#{params[:instance]}").to_json
  end

  get '/ssh/:role/:environment/:instance' do
    @host = $redis.hget("host:#{params[:role]}:#{params[:environment]}:#{params[:instance]}", 'hostname')
    @key = putkey(@host)
    {'hostname' => @host, 'key' => @key, 'pubkey' => @pubkey}.to_json
  end

end

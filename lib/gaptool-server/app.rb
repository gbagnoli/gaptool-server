#!/usr/bin/env ruby

require 'sinatra/base'
require 'sinatra'
require 'json'
require 'redis'
require 'yaml'
require 'erb'
require 'aws-sdk'
require 'openssl'
require 'net/ssh'

ENV['REDIS_HOST'] = 'localhost' unless ENV['REDIS_HOST']
ENV['REDIS_PORT'] = '6379' unless ENV['REDIS_PORT']
ENV['REDIS_PASS'] = nil unless ENV['REDIS_PASS']

class GaptoolServer < Sinatra::Base
  # Don't generate fancy HTML for stack traces.
  disable :show_exceptions
  # Allow errors to get out of the app so Cucumber can display them.
  enable :raise_errors

  def hash2redis( key, hash )
    hash.keys.each do |hkey|
      @redis.hset key, hkey, hash[hkey]
    end
  end

  before do
    @redis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_PORT'], :password => ENV['REDIS_PASS'])
    error 401 unless @redis.hget('users', env['HTTP_X_GAPTOOL_USER']) == env['HTTP_X_GAPTOOL_KEY']
    error 401 unless env['HTTP_X_GAPTOOL_USER'] && env['HTTP_X_GAPTOOL_KEY']
  end

  def putkey( host )
    @key = OpenSSL::PKey::RSA.new 2048
    @pubkey = "#{@key.ssh_type} #{[@key.to_blob].pack('m0')} GAPTOOL_GENERATED_KEY"
    ENV['SSH_AUTH_SOCK'] = ''
    Net::SSH.start(host, 'admin', :key_data => [@redis.hget('config', 'gaptoolkey')], :config => false, :keys_only => true, :paranoid => false) do |ssh|
      ssh.exec! "grep -v GAPTOOL_GENERATED_KEY ~/.ssh/authorized_keys > /tmp/pubkeys"
      ssh.exec! "cat /tmp/pubkeys > ~/.ssh/authorized_keys"
      ssh.exec! "rm /tmp/pubkeys"
      ssh.exec! "echo #{@pubkey} >> ~/.ssh/authorized_keys"
    end
    return @key.to_pem
  end

  def gt_securitygroup(role, environment, zone)
    AWS.config(:access_key_id => @redis.hget('config', 'aws_id'), :secret_access_key => @redis.hget('config', 'aws_secret'), :ec2_endpoint => "ec2.#{zone.chop}.amazonaws.com")
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

  def runservice(host, service, keys)
    Net::SSH.start(host, 'admin', :key_data => [@redis.hget('config', 'gaptoolkey')], :config => false, :keys_only => true, :paranoid => false) do |ssh|
      ssh.exec! "echo '#{keys.to_yaml}' > /tmp/apikeys-#{service}.yml"
      ssh.exec! "sudo restart #{service} || sudo start #{service}"
    end
  end

  def balanceservices(role, environment)
    @runnable = Array.new
    @available = Array.new
    @totalcap = 0
    @volume = 0
    @redis.keys("host:#{role}:#{environment}:*").each do |host|
      @available << {
        :hostname => @redis.hget(host, 'hostname'),
        :capacity => @redis.hget(host, 'capacity').to_i,
      }
      @totalcap = @totalcap + @redis.hget(host, 'capacity').to_i
    end
    @redis.keys("service:#{role}:#{environment}:*").each do |service|
      if @redis.hget(service, 'run').to_i == 1
        @runnable << {
          :name => @redis.hget(service, 'name'),
          :keys => eval(@redis.hget(service, 'keys')),
          :weight => @redis.hget(service, 'weight').to_i
        }
      end
    end
    @volume = 0
    @runnable.each do |service|
      @volume += service[:weight]
    end
    if @totalcap < @volume
      return {'error' => true,"message" => "This would overcommit, remove some resources or add nodes","totalcap" => @totalcap, "volume" => @volume}.to_json
    else
      @runnable.sort! { |x, y| x[:weight] <=> y[:weight] }
      @available.sort! { |x, y| x[:capacity] <=> y[:capacity] }
      @runlist = Array.new
      while @runnable != []
        @available.each do |host|
          break if @runnable.last.nil?
          if host[:capacity] >= @runnable.last[:weight]
            host[:capacity] = host[:capacity] - @runnable.last[:weight]
            @runlist << { :host => host, :service => @runnable.pop }
          end
        end
      end
      return @runlist
    end
  end

  get '/' do
    "You must be lost. Read the instructions."
  end

  get '/servicebalance/:role/:environment' do
    runlist = balanceservices(params[:role], params[:environment])
    runlist.each do |event|
      runservice(event[:host][:hostname], event[:service][:name], event[:service][:keys])
    end
  end

  put '/service/:role/:environment' do
    data = JSON.parse request.body.read
    count = @redis.incr("service:#{params[:role]}:#{params[:environment]}:#{data['name']}:count")
    key = "service:#{params[:role]}:#{params[:environment]}:#{data['name']}:#{count}"
    @redis.hset(key, 'name', data['name'])
    @redis.hset(key, 'keys', data['keys'])
    @redis.hset(key, 'weight', data['weight'])
    @redis.hset(key, 'role', params[:role])
    @redis.hset(key, 'environment', params[:environment])
    @redis.hset(key, 'run', data['enabled'])
    {
      :role => params[:role],
      :environment => params[:environment],
      :service => data['name'],
      :count => count,
    }.to_json
  end

  delete '/service/:role/:environment/:service' do
    if @redis.get("service:#{params[:role]}:#{params[:environment]}:#{params[:service]}:count") == '0'
      count = 0
    else
      count = @redis.decr("service:#{params[:role]}:#{params[:environment]}:#{params[:service]}:count")
      @redis.del("service:#{params[:role]}:#{params[:environment]}:#{params[:service]}:#{count + 1}")
    end
    {
      :role => params[:role],
      :environment => params[:environment],
      :service => params[:service],
      :count => count,
    }.to_json
  end

  get '/services' do
    services = Hash.new
    @redis.keys('service:*').each do |service|
      unless service.scan(':count') do
        services.merge!({ service['name'] => @redis.hgetall(service) })
        services[service['name']]['keys'] = eval(services[service['name']]['keys'])
      end
    end
    services.to_json
  end

  post '/regenhosts' do
    data = JSON.parse request.body.read
    AWS.config(:access_key_id => @redis.hget('config', 'aws_id'), :secret_access_key => @redis.hget('config', 'aws_secret'), :ec2_endpoint => "ec2.#{data['zone']}.amazonaws.com")
    @ec2 = AWS::EC2.new
    @redis.keys("host:*").each do |host|
      out = @redis.hset(host, 'hostname', @ec2.instances[@redis.hget(host, 'instance')].dns_name)
    end
    "{\"regen\":\"running\"}"
  end

  post '/init' do
    data = JSON.parse request.body.read
    AWS.config(:access_key_id => @redis.hget('config', 'aws_id'), :secret_access_key => @redis.hget('config', 'aws_secret'), :ec2_endpoint => "ec2.#{data['zone'].chop}.amazonaws.com")
    @ec2 = AWS::EC2.new
    # create shared secret to reference in /register
    @secret = (0...8).map{65.+(rand(26)).chr}.join
    data.merge!("secret" => @secret)
    sgid = gt_securitygroup(data['role'], data['environment'], data['zone'])
    if data['mirror']
      instance = @ec2.instances.create(
        :image_id => @redis.hget("amis", data['zone'].chop),
        :availability_zone => data['zone'],
        :instance_type => data['itype'],
        :key_name => "gaptool",
        :security_group_ids => sgid,
        :user_data => "#!/bin/bash\ncurl --silent -H 'X-GAPTOOL-USER: #{env['HTTP_X_GAPTOOL_USER']}' -H 'X-GAPTOOL-KEY: #{env['HTTP_X_GAPTOOL_KEY']}' #{@redis.hget('config', 'url')}/register -X PUT --data '#{data.to_json}' | bash",
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
        :image_id => @redis.hget("amis", data['zone'].chop),
        :availability_zone => data['zone'],
        :instance_type => data['itype'],
        :key_name => "gaptool",
        :security_group_ids => sgid,
        :user_data => "#!/bin/bash\ncurl --silent -H 'X-GAPTOOL-USER: #{env['HTTP_X_GAPTOOL_USER']}' -H 'X-GAPTOOL-KEY: #{env['HTTP_X_GAPTOOL_KEY']}' #{@redis.hget('config', 'url')}/register -X PUT --data '#{data.to_json}' | bash"
      )
    end
    # Add host tag
    instance.add_tag('Name', :value => "#{data['role']}-#{data['environment']}-#{instance.id}")
    # Create temporary redis entry for /register to pull the instance id
    @redis.set("instance:#{data['role']}:#{data['environment']}:#{@secret}", instance.id)
    "{\"instance\":\"#{instance.id}\"}"
  end

  post '/terminate' do
    data = JSON.parse request.body.read
    AWS.config(:access_key_id => @redis.hget('config', 'aws_id'), :secret_access_key => @redis.hget('config', 'aws_secret'), :ec2_endpoint => "ec2.#{data['zone']}.amazonaws.com")
    @ec2 = AWS::EC2.new
    begin
      @instance = @ec2.instances[data['id']]
      res = @instance.terminate
      res = @redis.del(@redis.keys("*#{data['id']}"))
      out = {data['id'] => {'status'=> 'terminated'}}
    rescue
      error 404
    end
    out.to_json
  end

  put '/register' do
    data = JSON.parse request.body.read
    AWS.config(:access_key_id => @redis.hget('config', 'aws_id'), :secret_access_key => @redis.hget('config', 'aws_secret'), :ec2_endpoint => "ec2.#{data['zone'].chop}.amazonaws.com")
    @ec2 = AWS::EC2.new
    @instance = @ec2.instances[@redis.get("instance:#{data['role']}:#{data['environment']}:#{data['secret']}")]
    hostname = @instance.dns_name
    delete = @redis.del("instance:#{data['role']}:#{data['environment']}:#{data['secret']}")
    @apps = Array.new
    @redis.keys("app:*").each do |app|
      if @redis.hget(app, 'role') == data['role']
        @apps << app.gsub('app:', '')
      end
    end
    data.merge!("capacity" => @redis.hget('capacity', data['itype']))
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
      'chefrepo' => @redis.hget('config', 'chefrepo'),
      'chefbranch' => @redis.hget('config', 'chefbranch'),
      'identity' => @redis.hget('config','initkey'),
      'appuser' => @redis.hget('config','appuser'),
      'apps' => @apps
    }.to_json
    erb :init
  end

  get '/hosts' do
    out = Array.new
    @redis.keys("host:*").each do |host|
      out << @redis.hgetall(host)
    end
    out.to_json
  end

  get '/apps' do
    out = Hash.new
    @redis.keys("app:*").each do |app|
      out.merge!(app => @redis.hgetall(app))
    end
    out.to_json
  end

  get '/hosts/:role' do
    out = Array.new
    @redis.keys("host:#{params[:role]}:*").each do |host|
      out << @redis.hgetall(host)
    end
    out.to_json
  end

  get '/hosts/:role/:environment' do
    out = Array.new
    @redis.keys("host:#{params[:role]}:#{params[:environment]}*").each do |host|
      out << @redis.hgetall(host)
    end
    out.to_json
  end

  get '/host/:role/:environment/:instance' do
    @redis.hgetall("host:#{params[:role]}:#{params[:environment]}:#{params[:instance]}").to_json
  end

  get '/ssh/:role/:environment/:instance' do
    @host = @redis.hget("host:#{params[:role]}:#{params[:environment]}:#{params[:instance]}", 'hostname')
    @key = putkey(@host)
    {'hostname' => @host, 'key' => @key, 'pubkey' => @pubkey}.to_json
  end


end

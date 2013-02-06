# encoding: utf-8
class GaptoolServer < Sinatra::Application

  get '/servicekeys/get/:service' do
    svcapi_getkey(params[:service])
  end

  get '/servicekeys/list/:service' do
    unless :service.nil?
      svcapi_showkeys(params[:service]).to_json
    else
      svcapi_showkeys(:all).to_json
    end
  end

  post '/servicekeys/release/:service' do
    data = JSON.parse request.body.read
    svcapi_releasekey(params[:service], data['key'])
  end

  put '/servicekeys/:service' do
    data = JSON.parse request.body.read
    svcapi_putkey(params[:service], data['key'])
  end

  delete '/servicekeys/:service' do
    svcapi_deletekey(params[:service], data['key'])
  end

  put '/service/:role/:environment' do
    data = JSON.parse request.body.read
    count = $redis.incr("service:#{params[:role]}:#{params[:environment]}:#{data['name']}:count")
    key = "service:#{params[:role]}:#{params[:environment]}:#{data['name']}:#{count}"
    $redis.hset(key, 'name', data['name'])
    $redis.hset(key, 'keys', data['keys'])
    $redis.hset(key, 'weight', data['weight'])
    $redis.hset(key, 'role', params[:role])
    $redis.hset(key, 'environment', params[:environment])
    $redis.hset(key, 'run', data['enabled'])
    {
      :role => params[:role],
      :environment => params[:environment],
      :service => data['name'],
      :count => count,
    }.to_json
  end

  delete '/service/:role/:environment/:service' do
    if $redis.get("service:#{params[:role]}:#{params[:environment]}:#{params[:service]}:count") == '0'
      count = 0
    else
      count = $redis.decr("service:#{params[:role]}:#{params[:environment]}:#{params[:service]}:count")
      service = eval($redis.range("running", 0, -1).grep(/scoring/).last)
      runservice(service[:hostname], params[:role], params[:environment], params[:service], 'stop')
      $redis.del("service:#{params[:role]}:#{params[:environment]}:#{params[:service]}:#{count + 1}")
    end
    {
      :role => params[:role],
      :environment => params[:environment],
      :service => params[:service],
      :count => count,
    }.to_json
  end

  get '/services' do
    getservices().to_json
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
end

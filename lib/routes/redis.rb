# encoding: utf-8
class GaptoolServer < Sinatra::Application
  post '/status/redis/llen' do
    data = JSON.parse request.body.read
    remotellen(data).to_json
  end
  post '/status/redis/lpush' do
    data = JSON.parse request.body.read
    remotelpush(data['list'], data['value']).to_json
  end
end

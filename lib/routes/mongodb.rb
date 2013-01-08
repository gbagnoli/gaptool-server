# encoding: utf-8
class GaptoolServer < Sinatra::Application
  post '/status/mongo/colcount' do
    data = JSON.parse request.body.read
    collectioncount(data).to_json
  end
end

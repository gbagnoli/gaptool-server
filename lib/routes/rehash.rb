# encoding: utf-8
class GaptoolServer < Sinatra::Application
  post '/rehash' do
    rehash().to_json
  end
end

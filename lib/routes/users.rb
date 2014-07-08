# encoding: utf-8

class GaptoolServer < Sinatra::Application
  @@prefix = '/users'

  get "#{@@prefix}", :can => [:read, User] do
    error 501
  end

  post "#{@@prefix}" do
    error 501
  end

  get "#{@@prefix}/:username" do
    error 501
  end

  put "#{@@prefix}/:username" do
    error 501
  end

  delete "#{@@prefix}/:username" do
    error 501
  end

  put "#{@@prefix}/:username/roles" do
    error 501
  end

  
end


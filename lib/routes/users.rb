# encoding: utf-8
require 'securerandom'
require 'digest/sha2'

class GaptoolServer < Sinatra::Application
  @@prefix = '/users'

  get "#{@@prefix}", :can => [:read, User] do
    json({:users => User.all.to_a.map{|u| u.username}})
  end

  post "#{@@prefix}", :can => [:create, User] do
    data = parse_body()
    error 400 unless data["role"]
    error 400 unless data["username"]
    data[:key] = (Digest::SHA2.new << SecureRandom.base64).to_s unless data[:key]
    if User.find(:username => data["username"]).first
      error 409
    end
    user = User.create(:username => data["username"],
                       :key => data[:key],
                       :role => data["role"])
    json(user.to_hash)
  end

  get "#{@@prefix}/:username" do
    return json(requested_user(params, :read).to_hash)
  end

  put "#{@@prefix}/:username" do
    user = requested_user(params, :edit)
    data = parse_body
    user.send("username=", data["username"]) if data.has_key?("username")
    user.send("key=", data["key"]) if data.has_key?("key")
    user.send("role=", data["role"]) if data.has_key?("role")
    user.save
    return json(user.to_hash)
  end

  delete "#{@@prefix}/:username" do
    user = requested_user(params, :delete)
    user.delete
    json({})
  end

  private

  def requested_user(params, perm)
    user = User.find(:username => params[:username]).first
    unless user
      error 404
    end
    authorize! perm, @user
    user
  end

  def parse_body
    begin
      return JSON.parse request.body.read
    rescue JSON::ParserError
      error 400
    end
  end

end

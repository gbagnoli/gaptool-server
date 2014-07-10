require 'test/unit'
require 'rack/test'

libpath = File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))
$:.unshift(libpath)
require "#{libpath}/app.rb"

Ohm.redis.call('FLUSHALL')

class GaptoolServerTestCase < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    GaptoolServer.new
  end

  def auth_headers_for(user)
    {'HTTP_X_GAPTOOL_USER' => user.username,
     'HTTP_X_GAPTOOL_KEY' => user.key}
  end

  def setup
    Ohm.redis.call('FLUSHALL')
    @admin = User.create :username => 'admin',
                         :key => 'admin',
                         :role => 'admin'
    @readonly = User.create :username => 'readonly',
                            :key => 'readonly',
                            :role => 'readonly'
  end
end

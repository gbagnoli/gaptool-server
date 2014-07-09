require 'test/unit'
require 'rack/test'
require_relative 'init'

class UserAPITests < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    GaptoolServer.new
  end

  def test_unauth
    get '/'
    assert last_response.status == 401
    #assert_equal 'You must be lost. Read the instructions.', last_response.body
  end

end

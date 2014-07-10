require_relative 'init'
class UserAPITests < GaptoolServerTestCase

    def test_unauth
      get '/'
      assert last_response.status == 401

    end

    def test_root_auth
      get '/', {}, auth_headers_for(@admin)
      assert last_response.status == 200
      assert_equal 'You must be lost. Read the instructions.', last_response.body
    end
end

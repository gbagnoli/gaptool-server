class Role < Ohm::Model
    attribute :name
    unique :name
    collection :users, :User
end

class User < Ohm::Model
    attribute :username
    attribute :key

    reference :role, :Role
    unique :username
    index :username

    def self.login(username, key)
      user = User.find(:username => username).first
      unless user and user.key == key
        return false
      end
      user
    end
end

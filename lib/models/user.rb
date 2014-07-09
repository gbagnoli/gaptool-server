class User < Ohm::Model
    attribute :username
    attribute :key
    attribute :role

    unique :username
    index :username
    index :role

    def self.login(username, key)
      user = User.find(:username => username).first
      unless user and user.key == key
        return false
      end
      user
    end

    def to_hash
      return {:username => username, :role => role, :key => key}
    end
end

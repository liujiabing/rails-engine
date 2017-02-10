module StandardFile
  class UserManager

    def initialize(user_class, salt_psuedo_nonce)
      @user_class = user_class
      @salt_psuedo_nonce = salt_psuedo_nonce
    end

    def sign_in(email, password)
      user = @user_class.find_by_email(email)
      if user and test_password(password, user.encrypted_password)
        return { user: user, token: jwt(user) }
      else
        return {:error => {:message => "Invalid email or password.", :status => 401}}
      end
    end

    def register(email, password, params)
      user = @user_class.find_by_email(email)
      if user
        return {:error => {:message => "Unable to register.", :status => 401}}
      else
        user = @user_class.new(:email => email, :encrypted_password => hash_password(password))
        user.update!(registration_params(params))
        return { user: user, token: jwt(user) }
      end
    end

    def change_pw(user, password, params)
      user.encrypted_password = hash_password(password)
      user.update!(registration_params(params))
      return { user: user, token: jwt(user) }
    end

    def auth_params(email)
      user = @user_class.find_by_email(email)
      pw_salt = user ? Digest::SHA1.hexdigest(email + "SN" + user.pw_nonce) : Digest::SHA1.hexdigest(email + "SN" + @salt_psuedo_nonce)
      pw_cost = user ? user.pw_cost : 5000
      pw_alg = user ? user.pw_alg : "sha512"
      pw_key_size = user ? user.pw_key_size : 512
      pw_func = user ? user.pw_func : "pbkdf2"
      return {:pw_func => pw_func, :pw_alg => pw_alg, :pw_salt => pw_salt, :pw_cost => pw_cost, :pw_key_size => pw_key_size}
    end

    private

    require "bcrypt"

    DEFAULT_COST = 11

    def hash_password(password)
      BCrypt::Password.create(password, cost: DEFAULT_COST).to_s
    end

    def test_password(password, hash)
      bcrypt = BCrypt::Password.new(hash)
      password = BCrypt::Engine.hash_secret(password, bcrypt.salt)
      return password == hash
    end

    def jwt(user)
      JwtHelper.encode({:user_uuid => user.uuid, :pw_hash => Digest::SHA256.hexdigest(user.encrypted_password)})
    end

    def registration_params(params)
      params.permit(:pw_func, :pw_alg, :pw_cost, :pw_key_size, :pw_nonce)
    end

  end
end

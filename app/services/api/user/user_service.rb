module Api
  module User
    class UserService
      class << self
        def find_or_create(token)
          result = CognitoTokenVerifier.verify_id_token(token)

          return result unless result.valid?

          user = PublicUsers::User.active[external_id: result.payload['sub']]
          user ||= PublicUsers::User.create(external_id: result.payload['sub'])
          user.email = result.payload['email']
          user
        end
      end
    end
  end
end

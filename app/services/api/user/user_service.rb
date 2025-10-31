module Api
  module User
    class UserService
      class << self
        def find_or_create(token)
          return nil if token.nil?

          if (payload = CognitoTokenVerifier.verify_id_token(token))
            user = PublicUsers::User.active[external_id: payload['sub']]
            user ||= PublicUsers::User.create(external_id: payload['sub'])
            user.email = payload['email']
            user
          end
        end
      end
    end
  end
end

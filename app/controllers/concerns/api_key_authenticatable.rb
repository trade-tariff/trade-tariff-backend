module ApiKeyAuthenticatable
  extend ActiveSupport::Concern

  included do
    private

    def authenticate_with_api_keys
      provided_key = request.headers['X-Api-Key']
      return false if provided_key.blank? || api_keys.blank?

      Rails.logger.debug "Provided key: #{provided_key}"

      key, config = api_keys.find do |api_key, _config|
        ActiveSupport::SecurityUtils.secure_compare(provided_key, api_key)
      end

      key.present?.tap do |authenticated|
        @client_id = config['client_id'] if authenticated
        @auth_type = 'x-api-key' if authenticated
      end
    end

    def api_keys
      @api_keys ||= read_api_keys
    end

    def read_api_keys
      api_key_hash = JSON.parse(TradeTariffBackend.green_lanes_api_keys)
      api_key_hash['api_keys']
    end
  end
end

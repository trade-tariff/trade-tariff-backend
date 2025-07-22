module RequestSpecHelper
  %i[head get post patch delete].each do |method|
    define_method "api_#{method}" do |path, **kwargs|
      public_send(method, path, **add_default_headers(**kwargs))
    end

    define_method "authenticated_#{method}" do |path, **kwargs|
      public_send(method, path, **add_authentication_header(**kwargs))
    end
  end

private

  def add_green_lanes_authentication_header(headers: {}, **kwargs)
    allow(TradeTariffBackend).to receive_messages(
      green_lanes_api_tokens: 'Trade-Tariff-Test',
      uk?: false,
    )

    headers['HTTP_AUTHORIZATION'] ||= ActionController::HttpAuthentication::Token.encode_credentials('Trade-Tariff-Test')

    kwargs.merge(headers:)
  end

  def add_authentication_header(headers: {}, **kwargs)
    headers['HTTP_AUTHORIZATION'] ||= 'Bearer tariff-api-test-token'

    kwargs.merge(headers:)
  end

  def add_default_headers(headers: {}, **kwargs)
    headers['Accept'] ||= 'application/vnd.hmrc.2.0+json'
    headers['Content-Type'] ||= 'application/json'

    kwargs.merge(headers:)
  end
end

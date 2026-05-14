module RequestSpecHelper
  %i[head get post put patch delete].each do |method|
    define_method "api_#{method}" do |path, **kwargs|
      public_send(method, path, **add_default_headers(**kwargs))
    end

    define_method "authenticated_#{method}" do |path, **kwargs|
      public_send(method, path, **add_authentication_header(**kwargs))
    end
  end

  def pagination_pattern
    { pagination:
      {
        page: 1,
        per_page: Integer,
        total_count: Integer,
      } }.ignore_extra_keys!
  end

  def request_headers(headers = request_header_overrides, format: :json, version: request_api_version)
    headers = headers.dup

    headers['Accept'] ||= "application/vnd.hmrc.#{version}.0+#{format}"
    headers['Content-Type'] ||= "application/#{format}"
    headers.delete_if { |_key, value| value.nil? }
  end

  def request_header_overrides
    {}
  end

  def request_api_version
    described_class.name.start_with?('Api::V1::') ? 1 : 2
  end

private

  def add_green_lanes_authentication_header(headers: {}, **kwargs)
    allow(TradeTariffBackend).to receive(:uk?).and_return(false)

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

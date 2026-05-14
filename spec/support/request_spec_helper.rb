module RequestSpecHelper
  LegacyRequest = Struct.new(:headers, keyword_init: true)

  %i[head get post put patch delete].each do |method|
    define_method "api_#{method}" do |path, **kwargs|
      public_send(method, path, **add_default_headers(**kwargs))
    end

    define_method "authenticated_#{method}" do |path, **kwargs|
      public_send(method, path, **add_authentication_header(**kwargs))
    end

    define_method method do |path_or_action, **kwargs|
      return super(path_or_action, **kwargs) unless path_or_action.is_a?(Symbol)

      request_method = legacy_controller_request_method(method, path_or_action)
      path = legacy_controller_action_path(path_or_action, kwargs, request_method)

      public_send(request_method, path, **legacy_controller_request_kwargs(kwargs, request_method))
      instance_variable_get(:@response)
    end
  end

  def request
    LegacyRequest.new(headers: legacy_request_headers)
  end

  def pagination_pattern
    { pagination:
      {
        page: 1,
        per_page: Integer,
        total_count: Integer,
      } }.ignore_extra_keys!
  end

private

  def legacy_controller_request_method(method, action)
    return :delete if method == :post && action == :destroy

    method
  end

  def legacy_request_headers
    @legacy_request_headers ||= {}
  end

  def legacy_controller_action_path(action, kwargs, method)
    params = kwargs.fetch(:params, {}) || {}
    route_params = params.merge(
      controller: described_class.controller_path,
      action: action.to_s,
      only_path: true,
    )
    route_params[:format] = kwargs[:format] if kwargs[:format]

    path = legacy_controller_route_set.url_helpers.url_for(route_params)
    return path if %i[get head].include?(method)

    path.split('?').first
  end

  def legacy_controller_route_set
    case described_class.name
    when /\AApi::Admin::/
      AdminApi.routes
    when /\AApi::Internal::/
      InternalApi.routes
    when /\AApi::User::/
      UserApi.routes
    when /\AApi::V1::/
      V1Api.routes
    when /\AApi::V2::/
      V2Api.routes
    else
      Rails.application.routes
    end
  end

  def legacy_controller_request_kwargs(kwargs, method)
    format = kwargs.delete(:format)
    kwargs.delete(:params) if %i[get head].include?(method)
    kwargs[:headers] = legacy_controller_headers(kwargs.fetch(:headers, {}), format)
    kwargs[:as] ||= :json if %i[post put patch delete].include?(method) && (format.nil? || format.to_sym == :json)
    kwargs
  end

  def legacy_controller_headers(headers, format)
    headers = request.headers.merge(headers)

    headers['Accept'] ||= if described_class.name.start_with?('Api::V1::')
                            "application/vnd.hmrc.1.0+#{format || 'json'}"
                          else
                            "application/vnd.hmrc.2.0+#{format || 'json'}"
                          end

    headers['Content-Type'] ||= "application/#{format || 'json'}"
    headers.delete_if { |_key, value| value.nil? }
  end

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

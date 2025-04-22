class ClearCacheControl
  FRONTEND_USER_AGENT = 'TradeTariffFrontend'.freeze
  HTTP_USER_AGENT = 'HTTP_USER_AGENT'.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    headers.delete(Rack::CACHE_CONTROL) unless frontend_request?(env)

    [status, headers, body]
  end

  private

  def frontend_request?(env)
    env[HTTP_USER_AGENT].to_s.start_with?(FRONTEND_USER_AGENT)
  end
end

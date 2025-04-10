class RemoveCacheControl
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    headers.delete(Rack::CACHE_CONTROL)

    [status, headers, body]
  end
end

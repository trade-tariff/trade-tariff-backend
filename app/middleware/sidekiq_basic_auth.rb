require 'rack/auth/basic'

class SidekiqBasicAuth < Rack::Auth::Basic
  def call(env)
    if env['PATH_INFO'].starts_with?('/sidekiq')
      super
    else
      @app.call(env)
    end
  end
end

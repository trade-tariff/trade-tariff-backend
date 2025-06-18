require 'rack/auth/basic'

class SidekiqBasicAuth < Rack::Auth::Basic
  AUTHENTICATED_PATHS = [
    '/xi/sidekiq',
    '/uk/sidekiq',
    '/sidekiq/',
  ].freeze

  def call(env)
    if AUTHENTICATED_PATHS.any? { |path| env['PATH_INFO'].start_with?(path) }
      super
    else
      @app.call(env)
    end
  end
end

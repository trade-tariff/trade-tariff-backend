class VersionedForwarder
  def call(env)
    path_params = env['action_dispatch.request.path_parameters'] || {}
    service = path_params[:service]
    version = path_params[:version]
    path = path_params[:path]

    # Reapply the router (and full middleware stack) with modified env
    Rails.application.call(transform_env(env, service, version, path))
  end

  private

  def transform_env(env, service, version, path)
    env['action_dispatch.old-path'] = env['PATH_INFO'].dup
    env['PATH_INFO'] = "/#{service}/api/#{path}"
    env['HTTP_ACCEPT'] = "application/vnd.hmrc.#{version}.0+json"
    env['action_dispatch.path-transformed'] = true
    env
  end
end

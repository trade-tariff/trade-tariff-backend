class VersionedForwarder
  def call(env)
    path_params = env['action_dispatch.request.path_parameters'] || {}
    service = path_params.fetch(:service, TradeTariffBackend.service)
    version = path_params[:version].to_f
    path = path_params[:path]
    env = transform_env(env, service, version, path)

    # Reapply the router (and full middleware stack) with modified env
    Rails.application.call(env)
  end

  private

  def transform_env(env, service, version, path)
    format = format_from(env)
    env['action_dispatch.old-path'] = env['PATH_INFO'].dup
    env['PATH_INFO'] = "/#{service}/api/#{path}#{format}"
    env['HTTP_ACCEPT'] = accept_from(format, version)
    env['action_dispatch.path-transformed'] = true
    env
  end

  def format_from(env)
    if env['REQUEST_PATH'].end_with?('.xml')
      '.xml'
    elsif env['REQUEST_PATH'].end_with?('.csv')
      '.csv'
    elsif env['REQUEST_PATH'].end_with?('.atom')
      '.atom'
    else
      ''
    end
  end

  def accept_from(format, version)
    ext = format.sub('.', '')
    ext = 'json' if ext.blank?
    "application/vnd.hmrc.#{version}+#{ext}"
  end
end

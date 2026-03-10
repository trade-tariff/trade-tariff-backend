# Extracts the trade tariff service ('uk' or 'xi') from the request URL prefix
# and stores it in TradeTariffRequest.service so that TradeTariffBackend.service
# returns the correct value for the duration of the request.
class SetRequestedService
  SERVICE_REGEX = %r{\A/(uk|xi)/}

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env['PATH_INFO'].to_s
    match = path.match(SERVICE_REGEX)
    TradeTariffRequest.service = match ? match[1] : nil

    @app.call(env)
  end
end

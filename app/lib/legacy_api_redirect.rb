# Redirects API paths with no service prefix (for example /api/v2/sections) to the
# same path under the current service (for example /uk/api/v2/sections).
#
# Uses 308 so that POST requests keep their method and body. The deprecation
# headers tell clients when the unprefixed path will stop working.
class LegacyApiRedirect
  SUNSET_DATE = Time.utc(2027, 4, 30)
  DOCS_URL = 'https://docs.trade-tariff.service.gov.uk/reference.html'.freeze

  def call(env)
    request = Rack::Request.new(env)

    headers = {
      'Location' => "/#{TradeTariffBackend.service}#{request.fullpath}",
      'Deprecation' => 'true',
      'Sunset' => SUNSET_DATE.httpdate,
      'Link' => %(<#{DOCS_URL}>; rel="deprecation"),
    }

    [308, headers, []]
  end
end

# Redirects API paths with no service prefix (for example /api/v2/sections) to the
# same path under the current service (for example /uk/api/v2/sections).
#
# Uses 308 so that POST requests keep their method and body. The deprecation
# headers tell clients when the unprefixed path will stop working.
class LegacyApiRedirect
  DEPRECATION_DATE = Time.utc(2026, 10, 15)
  SUNSET_DATE = Time.utc(2027, 4, 30)
  DOCS_URL = 'https://docs.trade-tariff.service.gov.uk/reference.html'.freeze

  def call(env)
    # original_fullpath is captured before HandleApiGatewayParams rewrites
    # QUERY_STRING, so dotted names such as filter.type survive the redirect.
    request = ActionDispatch::Request.new(env)

    # Rack 3 requires lowercase response header names.
    # Deprecation is an RFC 9745 Structured Field Date: "@" plus Unix seconds.
    headers = {
      'location' => "/#{TradeTariffBackend.service}#{request.original_fullpath}",
      'deprecation' => "@#{DEPRECATION_DATE.to_i}",
      'sunset' => SUNSET_DATE.httpdate,
      'link' => %(<#{DOCS_URL}>; rel="deprecation"),
    }

    [308, headers, []]
  end
end

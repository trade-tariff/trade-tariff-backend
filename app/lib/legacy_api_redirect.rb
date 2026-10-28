# Redirects API paths with no service prefix (for example /api/v2/sections) to the
# same path under the current service (for example /uk/api/v2/sections).
#
# Uses 308 so that POST requests keep their method and body. The deprecation
# headers tell clients when the unprefixed path will stop working.
class LegacyApiRedirect
  DEPRECATION_DATE = Time.utc(2026, 10, 15)
  SUNSET_DATE = Time.utc(2027, 4, 30)
  V1_ACCEPT_HEADER = VersionedAcceptHeader.new(version: 1.0)
  DOCS_URL = 'https://docs.trade-tariff.service.gov.uk/reference.html'.freeze

  def call(env)
    request = ActionDispatch::Request.new(env)

    # A client that sends a v1 Accept header used to be served v2, because
    # VersionedForwarder sets Accept from the URL version. After a redirect the
    # v1 catch-all route would answer 404, so these clients are not redirected.
    return VersionedForwarder.new.call(env) if V1_ACCEPT_HEADER.matches?(request)

    # original_fullpath is captured before HandleApiGatewayParams rewrites
    # QUERY_STRING, so dotted names such as filter.type survive the redirect.

    # Rack 3 requires lowercase response header names. Rack::Headers lowercases
    # every key on assignment, including keys that later middleware adds (for
    # example X-Path-Transformed in HandleGoodsNomenclature). A plain Hash would not.
    headers = Rack::Headers.new
    headers['location'] = "/#{TradeTariffBackend.service}#{request.original_fullpath}"
    # Deprecation is an RFC 9745 Structured Field Date: "@" plus Unix seconds.
    headers['deprecation'] = "@#{DEPRECATION_DATE.to_i}"
    headers['sunset'] = SUNSET_DATE.httpdate
    headers['link'] = %(<#{DOCS_URL}>; rel="deprecation")

    [308, headers, []]
  end
end

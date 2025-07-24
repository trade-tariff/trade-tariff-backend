class VersionedAcceptHeader
  DEFAULT_VERSION = '2.0'.freeze
  VERSION_REGEX = /\Aapplication\/vnd\.hmrc\.(?<version>\d+\.\d+)\+(?<format>.*)\z/

  def initialize(version:)
    @version = version.to_s
  end

  def matches?(request)
    accept = request.headers['ACCEPT'].to_s[0, 255]

    return @version == DEFAULT_VERSION if accept.blank?

    match = accept.match(VERSION_REGEX)

    if match
      match[:version] == @version
    else
      # NOTE: Use V2 when the accept header does not match the expected format (for example chrome-based
      #       browsers send 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7'
      #       when links are clicked in a UI
      @version == DEFAULT_VERSION
    end
  end
end

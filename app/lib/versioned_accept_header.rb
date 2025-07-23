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

    match&.[](:version) == @version
  end
end

class ApiConstraints
  VERSION_HEADER_MATCHER = %r{application/vnd\.uktt\.v\d}

  class << self
    def default_version
      ENV.fetch('DEFAULT_API_VERSION', '1')
    end
  end

  def initialize(version:)
    @version = version.to_s
  end

  def matches?(req)
    if uktt_version_header_present?(req)
      requested_version?(req)
    else
      default?
    end
  end

  private

  def default?
    @version == self.class.default_version
  end

  def uktt_version_header_present?(req)
    req.headers['Accept'].to_s.match? VERSION_HEADER_MATCHER
  end

  def requested_version?(req)
    req.headers['Accept'].to_s.include?("application/vnd.uktt.v#{@version}")
  end
end

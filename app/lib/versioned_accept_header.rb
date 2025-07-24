class VersionedAcceptHeader
  def initialize(version:)
    @version = version.to_s
  end

  def matches?(req)
    req.headers['ACCEPT'].to_s.include?("application/vnd.hmrc.#{@version}+json")
  end
end

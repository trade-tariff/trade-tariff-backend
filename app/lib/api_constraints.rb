class ApiConstraints
  def initialize(version:)
    @version = version.to_s
  end

  def matches?(req)
    default? || req.headers['Accept'].to_s.include?("application/vnd.uktt.v#{@version}")
  end

  private

  def default?
    @version == default
  end

  def default
    ENV.fetch('DEFAULT_API_VERSION', '1')
  end
end

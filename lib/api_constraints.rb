class ApiConstraints
  def initialize(version:)
    @version = version
  end

  def matches?(req)
    is_default? || req.headers['Accept'].include?("application/vnd.uktt.v#{@version}")
  end

  private

  def is_default?
    if Rails.env.production?
      production_default?
    else
      development_default?
    end
  end

  def development_default?
    @version == 2
  end

  def production_default?
    @version == 1
  end
end

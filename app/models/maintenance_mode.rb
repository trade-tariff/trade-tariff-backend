class MaintenanceMode
  class MaintenanceModeActive < RuntimeError; end

  class << self
    delegate :active?, :check!, to: :new
  end

  def active?(bypass_param = nil)
    enabled? && !bypass_matches?(bypass_param)
  end

  def check!(bypass_param = nil)
    raise MaintenanceModeActive if active? bypass_param
  end

private

  def enabled?
    ENV['MAINTENANCE'].present?
  end

  def bypass_matches?(bypass_param)
    ENV['MAINTENANCE_BYPASS'].present? && ENV['MAINTENANCE_BYPASS'] == bypass_param
  end
end

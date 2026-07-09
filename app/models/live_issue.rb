class LiveIssue < Sequel::Model(Sequel[:live_issues].qualify(:public))
  COMMODITY_CODE_PATTERN = /\A\d{10}\z/

  plugin :timestamps, update_on_create: true
  plugin :auto_validations, not_null: :presence

  def validate
    super

    validates_includes %w[Active Resolved], :status
    errors.add(:commodities, 'must contain 10 digit commodity codes') if invalid_commodity_codes?
  end

private

  def invalid_commodity_codes?
    return false if commodities.blank?
    return true if commodities.is_a?(String) || !commodities.respond_to?(:any?)

    commodities.any? { |commodity| !commodity.is_a?(String) || !commodity.match?(COMMODITY_CODE_PATTERN) }
  end
end

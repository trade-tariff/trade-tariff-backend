class CustomsTariffGeneralRule < Sequel::Model
  many_to_one :customs_tariff_update, key: :customs_tariff_update_version

  def self.latest_rules
    latest_update = CustomsTariffUpdate
      .latest
      .eager(:customs_tariff_general_rules)
      .first
    return [] unless latest_update

    latest_update.customs_tariff_general_rules
  end
end

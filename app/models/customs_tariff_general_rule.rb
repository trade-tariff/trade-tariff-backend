class CustomsTariffGeneralRule < Sequel::Model
  PENDING  = 'pending'.freeze
  APPROVED = 'approved'.freeze
  REJECTED = 'rejected'.freeze

  many_to_one :customs_tariff_update, key: :customs_tariff_update_version

  def self.latest_rules
    latest_update = CustomsTariffUpdate
      .latest
      .eager(:customs_tariff_general_rules)
      .first
    return [] unless latest_update

    latest_update.customs_tariff_general_rules
  end

  dataset_module do
    def pending
      where(status: PENDING)
    end

    def approved
      where(status: APPROVED)
    end

    def rejected
      where(status: REJECTED)
    end
  end
end

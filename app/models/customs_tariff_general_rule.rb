class CustomsTariffGeneralRule < Sequel::Model
  PENDING  = 'pending'.freeze
  APPROVED = 'approved'.freeze
  REJECTED = 'rejected'.freeze

  many_to_one :customs_tariff_update, key: :customs_tariff_update_version

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

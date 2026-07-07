class CustomsTariffUpdate < Sequel::Model
  set_primary_key :version
  unrestrict_primary_key

  plugin :time_machine
  plugin :timestamps, update_on_create: true

  PENDING = 'pending'.freeze
  APPROVED          = 'approved'.freeze
  REJECTED          = 'rejected'.freeze
  FAILED            = 'failed'.freeze

  one_to_many :customs_tariff_chapter_notes, key: :customs_tariff_update_version
  one_to_many :customs_tariff_section_notes, key: :customs_tariff_update_version
  one_to_many :customs_tariff_general_rules, key: :customs_tariff_update_version, order: :rule_label

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

    def failed
      where(status: FAILED)
    end

    def latest
      actual.exclude(status: FAILED).order(Sequel.desc(:validity_start_date))
    end
  end
end

class CustomsTariffUpdate < Sequel::Model
  set_primary_key :version
  unrestrict_primary_key

  plugin :time_machine
  plugin :timestamps, update_on_create: true

  AWAITING_APPROVAL = 'awaiting_approval'.freeze
  APPROVED          = 'approved'.freeze
  REJECTED          = 'rejected'.freeze
  FAILED            = 'failed'.freeze

  one_to_many :customs_tariff_chapter_notes, key: :customs_tariff_update_version
  one_to_many :customs_tariff_section_notes, key: :customs_tariff_update_version
  one_to_many :customs_tariff_general_rules, key: :customs_tariff_update_version

  dataset_module do
    def awaiting_approval
      where(status: AWAITING_APPROVAL)
    end

    def approved
      where(status: APPROVED)
    end

    def failed
      where(status: FAILED)
    end
  end
end

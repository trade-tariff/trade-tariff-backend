class CustomsTariffUpdate < Sequel::Model
  set_primary_key :version
  unrestrict_primary_key

  plugin :time_machine
  plugin :timestamps, update_on_create: true

  one_to_many :customs_tariff_chapter_notes, key: :customs_tariff_update_version
  one_to_many :customs_tariff_section_notes, key: :customs_tariff_update_version
  one_to_many :customs_tariff_general_rules, key: :customs_tariff_update_version, order: :rule_label

  dataset_module do
    def failed   = exclude(import_error: nil)
    def imported = where(import_error: nil)
    def latest   = imported.actual.order(Sequel.desc(:validity_start_date))
  end
end

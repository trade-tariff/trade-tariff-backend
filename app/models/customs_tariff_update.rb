class CustomsTariffUpdate < Sequel::Model
  set_primary_key :version
  unrestrict_primary_key

  plugin :time_machine
  plugin :timestamps, update_on_create: true

  one_to_many :customs_tariff_chapter_notes, key: :customs_tariff_update_version
  one_to_many :customs_tariff_section_notes, key: :customs_tariff_update_version
  one_to_many :customs_tariff_general_rules, key: :customs_tariff_update_version, order: :rule_label

  def note_reimport_validity
    baseline_end = self.class.where(version: 'legacy-notes-before-2026-11-04').get(:validity_end_date)
    cutover = baseline_end && baseline_end + 1

    if cutover && validity_start_date <= cutover
      # Preserve the migration's retained version without recreating pre-launch history.
      retained_version = self.class.imported
        .where { validity_start_date <= cutover }
        .where(Sequel.|({ validity_end_date: nil }, Sequel[:validity_end_date] >= cutover))
        .order(Sequel.desc(:validity_start_date), Sequel.desc(:version))
        .get(:version)

      return unless version == retained_version
    end

    {
      validity_start_date: [validity_start_date, cutover].compact.max,
      validity_end_date:,
    }
  end

  dataset_module do
    def failed   = exclude(import_error: nil)
    def imported = where(import_error: nil)
    def latest   = imported.actual.order(Sequel.desc(:validity_start_date))
  end
end

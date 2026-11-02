Sequel.migration do
  up do
    # Use the deployment's SERVICE search path. UK and XI must each run this migration.
    baseline_version = 'legacy-notes-before-2026-11-04'
    next if self[:customs_tariff_updates].where(version: baseline_version).any?

    cutover = Date.new(2026, 11, 4)
    baseline_start = Date.new(1900, 1, 1)
    updates = self[:customs_tariff_updates]
    current = updates.where(import_error: nil)
                     .where { validity_start_date <= cutover }
                     .where(Sequel.|({ validity_end_date: nil }, Sequel[:validity_end_date] >= cutover))
                     .order(Sequel.desc(:validity_start_date), Sequel.desc(:version))
                     .first

    note_tables = {
      customs_tariff_chapter_notes: [:chapter_notes, :chapter_id],
      customs_tariff_section_notes: [:section_notes, :section_id],
    }

    unless current && note_tables.keys.all? { |table| self[table].where(customs_tariff_update_version: current[:version]).any? }
      raise 'Cannot migrate notes without an extracted chapter and section note set for 2026-11-04'
    end

    # Keep original document dates and general rules. Only replace pre-launch note history.
    prelaunch_versions = updates.where { validity_start_date <= cutover }.select(:version)
    note_tables.each_key do |table|
      self[table].where(customs_tariff_update_version: prelaunch_versions)
                 .exclude(customs_tariff_update_version: current[:version]).delete
      self[table].where(customs_tariff_update_version: current[:version])
                 .update(validity_start_date: cutover, validity_end_date: current[:validity_end_date])
    end

    now = Time.current
    updates.insert(version: baseline_version, validity_start_date: baseline_start,
                   validity_end_date: cutover - 1, created_at: now, updated_at: now)

    note_tables.each do |target, (source, key)|
      self[target].insert(
        %i[customs_tariff_update_version content validity_start_date validity_end_date] + [key],
        self[source].select(Sequel.as(baseline_version, :customs_tariff_update_version), :content,
                            Sequel.as(baseline_start, :validity_start_date),
                            Sequel.as(cutover - 1, :validity_end_date), key),
      )
    end
  end

  down do
    # Irreversible: superseded extracted note rows cannot be reconstructed here.
  end
end

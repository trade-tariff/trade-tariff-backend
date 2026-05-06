# Idempotent: only updates rows where validity_start_date IS NULL.
# Records already populated (by this migration or the updated importer) are untouched.
Sequel.migration do
  up do
    %i[customs_tariff_section_notes customs_tariff_chapter_notes customs_tariff_general_rules].each do |table|
      run <<~SQL
        UPDATE #{table}
        SET validity_start_date = customs_tariff_updates.validity_start_date,
            status = CASE customs_tariff_updates.status
                       WHEN 'failed' THEN 'pending'
                       ELSE customs_tariff_updates.status
                     END
        FROM customs_tariff_updates
        WHERE #{table}.customs_tariff_update_version = customs_tariff_updates.version
          AND #{table}.validity_start_date IS NULL
      SQL
    end
  end

  down do
    # Not reversible — restoring nulls would discard legitimately set dates.
  end
end

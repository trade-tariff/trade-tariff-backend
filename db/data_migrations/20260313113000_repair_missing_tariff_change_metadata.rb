# frozen_string_literal: true

Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      puts "Repairing missing TariffChange metadata for Measure records..."

      query = TariffChange.where(type: 'Measure')
                          .where(Sequel.lit("metadata IS NULL OR metadata = '{}'::jsonb"))

      processed = 0
      skipped = 0
      total = query.count

      query.paged_each(rows_per_fetch: 1000) do |tariff_change|
        metadata = TariffChangesService::MeasureMetadataGenerator.call(tariff_change.object_sid)

        if metadata.blank?
          skipped += 1
          next
        end

        tariff_change.update(metadata: Sequel.pg_jsonb(metadata))
        processed += 1

        puts "Processed #{processed}/#{total} records..." if (processed % 1000).zero?
      end

      missing_after = Sequel::Model.db.fetch(<<~SQL).first[:count]
        SELECT COUNT(*)
        FROM uk.tariff_changes tc
        WHERE tc.type = 'Measure'
          AND (tc.metadata IS NULL OR tc.metadata = '{}'::jsonb)
      SQL

      puts "Skipped Measure records without oplog metadata: #{skipped}"
      puts "Remaining Measure records with missing metadata: #{missing_after}"
    end
  end

  down do
    # No-op: this migration repairs missing metadata.
  end
end

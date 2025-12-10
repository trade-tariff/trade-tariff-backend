# frozen_string_literal: true

Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      puts "Adding metadata to TariffChange records"

      processed = 0
      query = TariffChange.where(type: 'Measure')
                          .where(Sequel.lit("metadata IS NULL OR metadata = '{}'::jsonb"))
      total = query.count
      service = TariffChangesService.new(Time.zone.today)

      query.paged_each(rows_per_fetch: 1000) do |tc|
        raw_metadata = service.send(:generate_measure_metadata, tc.object_sid)

        next if raw_metadata.nil?

        metadata_hash = raw_metadata.is_a?(String) ? JSON.parse(raw_metadata) : raw_metadata
        tc.update(metadata: Sequel.pg_jsonb(metadata_hash))

        processed += 1
        if processed % 1000 == 0
          puts "Processed #{processed}/#{total} records..."
        end
      end

      puts "Completed backfilling #{processed} TariffChange records with metadata"
    end
  end
end

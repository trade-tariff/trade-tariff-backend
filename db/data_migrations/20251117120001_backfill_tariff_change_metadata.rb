# frozen_string_literal: true

Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      puts "Backfilling TariffChange records with metadata..."

      processed = 0
      total = TariffChange.where(type: 'Measure').count

      TariffChange.where(type: 'Measure').paged_each(rows_per_fetch: 1000) do |tc|
        measure = Measure.first(measure_sid: tc.object_sid)
        next unless measure

        measure_type = MeasureType.first(measure_type_id: measure.measure_type_id)
        excluded_areas = MeasureExcludedGeographicalArea
                          .where(measure_sid: measure.measure_sid)
                          .map(&:excluded_geographical_area)
                          .sort

        metadata = {
          measure: {
            measure_type_id: measure.measure_type_id,
            trade_movement_code: measure_type&.trade_movement_code,
            geographical_area_id: measure.geographical_area_id,
            excluded_geographical_area_ids: excluded_areas,
          }
        }

        tc.update(metadata: Sequel.pg_jsonb(metadata))

        processed += 1
        if processed % 1000 == 0
          puts "Processed #{processed}/#{total} records..."
        end
      end

      puts "Completed backfilling #{processed} TariffChange records with metadata"
    end
  end

  down do
    if TradeTariffBackend.uk?
      TariffChange.update(metadata: '{}')
    end
  end
end

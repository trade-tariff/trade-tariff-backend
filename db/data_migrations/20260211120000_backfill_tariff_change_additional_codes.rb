# frozen_string_literal: true

Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      puts "Backfilling additional_code in TariffChange metadata..."

      Sequel::Model.db.run(<<~SQL)
        WITH latest_desc AS (
          SELECT DISTINCT ON (acd.additional_code_sid)
            acd.additional_code_sid,
            acd.additional_code_type_id,
            acd.additional_code,
            acd.description
          FROM uk.additional_code_descriptions acd
          JOIN uk.additional_code_description_periods adp
            ON adp.additional_code_description_period_sid = acd.additional_code_description_period_sid
          WHERE acd.language_id = 'EN'
          ORDER BY acd.additional_code_sid, adp.validity_start_date DESC
        )
        UPDATE uk.tariff_changes tc
        SET metadata = jsonb_set(
          COALESCE(tc.metadata, '{}'::jsonb),
          '{measure,additional_code}',
          to_jsonb(ld.additional_code_type_id || ld.additional_code || ': ' || ld.description),
          true
        )
        FROM uk.measures m
        JOIN latest_desc ld ON ld.additional_code_sid = m.additional_code_sid
        WHERE tc.type = 'Measure'
          AND tc.object_sid = m.measure_sid
          AND (tc.metadata->'measure'->>'additional_code' IS NULL OR tc.metadata->'measure'->>'additional_code' = '');
      SQL
    end
  end

  down do
    # No-op - we don't want to remove the additional_code data
  end
end

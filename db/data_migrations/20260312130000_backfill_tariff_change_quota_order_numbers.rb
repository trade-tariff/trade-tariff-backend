# frozen_string_literal: true

Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      puts "Backfilling quota_order_number in TariffChange metadata..."

      Sequel::Model.db.run(<<~SQL)
        UPDATE uk.tariff_changes tc
        SET metadata = jsonb_set(
          COALESCE(tc.metadata, '{}'::jsonb),
          '{measure,quota_order_number}',
          to_jsonb(m.ordernumber),
          true
        )
        FROM uk.measures m
        WHERE tc.type = 'Measure'
          AND tc.object_sid = m.measure_sid
          AND tc.metadata->'measure'->>'quota_order_number' IS NULL;
      SQL
    end
  end

  down do
    # No-op - we don't want to remove backfilled quota_order_number data
  end
end

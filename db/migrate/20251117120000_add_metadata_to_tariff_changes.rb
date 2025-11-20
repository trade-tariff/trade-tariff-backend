# frozen_string_literal: true

Sequel.migration do
  change do
    return unless TradeTariffBackend.uk?

    alter_table :tariff_changes do
      add_column :metadata, :jsonb, default: '{}'
    end

    # Add GIN index for efficient JSONB queries
    add_index :tariff_changes, :metadata, type: :gin

    # Add specific index for common measure queries
    execute <<-SQL
      CREATE INDEX idx_tariff_changes_measure_metadata
      ON tariff_changes USING GIN ((metadata->'measure'))
      WHERE type = 'Measure'
    SQL
  end
end

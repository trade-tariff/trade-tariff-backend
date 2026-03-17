# frozen_string_literal: true

Sequel.migration do
  up do
    tables_by_schema = {
      uk: %w[
        chapters_guides
        clear_caches
        exchange_rate_countries
        exchange_rate_currencies
        tariff_update_conformance_errors
        users
      ],
      xi: %w[
        chapters_guides
        clear_caches
        exchange_rate_countries
        exchange_rate_currencies
        tariff_update_conformance_errors
        users
      ],
    }

    tables_by_schema.each do |schema, tables|
      tables.each do |table|
        run "DROP TABLE IF EXISTS #{schema}.#{table} CASCADE"
      end
    end
  end

  down do
    raise Sequel::Error, 'remove_unused_legacy_tables is irreversible'
  end
end

# frozen_string_literal: true

Sequel.migration do
  LEGACY_TABLES = %i[
    chapters_guides
    clear_caches
    exchange_rate_countries
    exchange_rate_currencies
    tariff_update_conformance_errors
    users
  ].freeze

  up do
    # These are legacy service-schema tables only.
    # Keep public.users, which backs the current public user/subscription models.
    service_schema = TradeTariffBackend.service.to_sym

    LEGACY_TABLES.each do |table|
      drop_table?(Sequel[table].qualify(service_schema), cascade: true)
    end
  end

  down do
    raise Sequel::Error, 'remove_unused_legacy_tables is irreversible'
  end
end

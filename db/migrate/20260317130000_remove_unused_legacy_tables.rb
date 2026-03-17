# frozen_string_literal: true

Sequel.migration do
  up do
    %i[
      chapters_guides
      clear_caches
      exchange_rate_countries
      exchange_rate_currencies
      tariff_update_conformance_errors
      users
    ].each do |table|
      drop_table?(table, cascade: true)
    end
  end

  down do
    raise Sequel::Error, 'remove_unused_legacy_tables is irreversible'
  end
end

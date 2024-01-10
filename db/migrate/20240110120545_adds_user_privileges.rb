# frozen_string_literal: true

Sequel.migration do
  up do
    run %(
      GRANT SELECT ON ALL TABLES IN SCHEMA uk TO tariff_read;
      GRANT SELECT ON ALL TABLES IN SCHEMA xi TO tariff_read;
    )
  end

  down do
    # NOOP
  end
end

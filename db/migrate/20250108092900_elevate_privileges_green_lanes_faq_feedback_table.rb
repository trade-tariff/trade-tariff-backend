# frozen_string_literal: true

Sequel.migration do
  up do
    execute <<-SQL
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tariff_read') THEN
          GRANT INSERT, UPDATE, DELETE ON TABLE uk.green_lanes_faq_feedback TO tariff_read;
          GRANT INSERT, UPDATE, DELETE ON TABLE xi.green_lanes_faq_feedback TO tariff_read;
        END IF;
      END
      $$;
    SQL
  end

  down do
    execute <<-SQL
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tariff_read') THEN
          REVOKE INSERT, UPDATE, DELETE ON TABLE uk.green_lanes_faq_feedback FROM tariff_read;
          REVOKE INSERT, UPDATE, DELETE ON TABLE xi.green_lanes_faq_feedback FROM tariff_read;
        END IF;
      END
      $$;
    SQL
  end
end
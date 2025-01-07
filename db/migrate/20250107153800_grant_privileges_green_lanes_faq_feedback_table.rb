# frozen_string_literal: true

user = 'tariff_read'

Sequel.migration do
  change do
    run %{
      DO
      $do$
      BEGIN
         IF EXISTS (
            SELECT FROM pg_catalog.pg_roles
            WHERE  rolname = '#{user}') THEN
            GRANT ALL PRIVILEGES ON TABLE green_lanes_faq_feedback TO #{user};
         END IF;
      END
      $do$;
    }
  end
end

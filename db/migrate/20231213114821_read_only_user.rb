# frozen_string_literal: true

user = 'tariff_read'

Sequel.migration do
  up do
    run %{
        DO
        $do$
        BEGIN
           IF EXISTS (
              SELECT FROM pg_catalog.pg_roles
              WHERE  rolname = '#{user}') THEN
              RAISE NOTICE 'Role "#{user}" already exists. Skipping.';
           ELSE
              CREATE USER #{user} WITH PASSWORD 'tariff';
              ALTER DEFAULT PRIVILEGES IN SCHEMA uk GRANT SELECT ON TABLES TO #{user};
              ALTER DEFAULT PRIVILEGES IN SCHEMA xi GRANT SELECT ON TABLES TO #{user};
              ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO #{user};
           END IF;
        END
        $do$;
      }
  end

  down do
    run %{
      REVOKE ALL PRIVILEGES ON SCHEMA uk FROM #{user};
      REVOKE ALL PRIVILEGES ON SCHEMA xi FROM #{user};
      REVOKE ALL PRIVILEGES ON SCHEMA public FROM #{user};
      ALTER DEFAULT PRIVILEGES IN SCHEMA uk REVOKE SELECT ON TABLES FROM #{user};
      ALTER DEFAULT PRIVILEGES IN SCHEMA xi REVOKE SELECT ON TABLES FROM #{user};
      ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE SELECT ON TABLES FROM #{user};
      DROP OWNED BY #{user};
      DROP USER IF EXISTS #{user};
    }
  end
end

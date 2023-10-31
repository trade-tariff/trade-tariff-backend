# frozen_string_literal: true

user = 'tariff_read'
db = Sequel::Model.db

Sequel.migration do
  up do
    # Create a user with SELECT on all tables, including tables created after this migration
    db.run(sprintf('CREATE USER %s', user))
    db.run(sprintf('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO %s', user))
  end

  down do
    db.run(sprintf('ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE SELECT ON TABLES FROM %s', user))
    db.run(sprintf('DROP USER IF EXISTS %s', user))
  end
end

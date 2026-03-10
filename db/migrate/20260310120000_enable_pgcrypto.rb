Sequel.migration do
  up do
    run 'CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public'
  end

  down do
    run 'DROP EXTENSION IF EXISTS pgcrypto'
  end
end

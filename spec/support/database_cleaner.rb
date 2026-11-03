db = Sequel::DATABASES.first

truncation_tables = db.fetch(<<~SQL).map { |row| row[:qualified_name] }
  SELECT quote_ident(pg_namespace.nspname) || '.' || quote_ident(pg_class.relname) AS qualified_name
  FROM pg_class
  INNER JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
  WHERE pg_class.relkind IN ('r', 'p')
    AND pg_namespace.nspname NOT IN ('pg_catalog', 'information_schema')
    AND pg_namespace.nspname NOT LIKE 'pg_toast%'
    AND pg_class.relname NOT IN ('schema_info', 'schema_migrations', 'ar_internal_metadata')
SQL

truncate_all_tables = lambda do
  next if truncation_tables.empty?

  db.run <<~SQL
    TRUNCATE TABLE #{truncation_tables.join(', ')} RESTART IDENTITY CASCADE
  SQL
end

RSpec.configure do |config|
  # Only allow CI postgresql as 'remote' URL, no others
  # Future versions of DatabaseCleaner (> 1.7.0?) will allow a whitelist instead
  if ENV.fetch('DATABASE_URL', '').start_with?('postgresql://postgres:postgres@postgres:5432/')
    DatabaseCleaner.allow_remote_database_url = true
  end

  DatabaseCleaner.strategy = :transaction

  config.before(:suite) do
    truncate_all_tables.call
  end

  config.around(:each, :truncation) do |example|
    truncate_all_tables.call
    example.run
    truncate_all_tables.call
  end

  config.around do |example|
    if example.metadata[:truncation]
      example.run
    else
      DatabaseCleaner.start
      example.run
      DatabaseCleaner.clean
    end
  end
end

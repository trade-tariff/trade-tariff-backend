RSpec.configure do |config|
  # Only allow CI postgresql as 'remote' URL, no others
  # Future versions of DatabaseCleaner (> 1.7.0?) will allow a whitelist instead
  if ENV.fetch('DATABASE_URL', '').start_with?('postgresql://postgres:postgres@postgres:5432/')
    DatabaseCleaner.allow_remote_database_url = true
  end

  DatabaseCleaner.strategy = :transaction

  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each, :truncation) do |example|
    DatabaseCleaner.strategy = :truncation
    example.run
    DatabaseCleaner.strategy = :transaction
  end

  config.around do |example|
    DatabaseCleaner.start
    example.run
    DatabaseCleaner.clean
  end
end

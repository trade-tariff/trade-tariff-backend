require 'open3'

namespace :db do
  namespace :test do
    desc 'Populate empty materialized views after loading the test structure'
    task populate_empty_materialized_views: :environment do
      db = begin
        Sequel::Model.db
      rescue Sequel::Error
        Sequel.connect(Rails.application.config.database_configuration.fetch(Rails.env).symbolize_keys)
      end

      db.fetch(<<~SQL).each do |row|
        SELECT quote_ident(schemaname) || '.' || quote_ident(matviewname) AS view_name
        FROM pg_matviews
      SQL
        db.run("REFRESH MATERIALIZED VIEW #{row[:view_name]}")
      end
    end

    desc 'Prepare parallel test databases'
    task prepare_parallel: :environment do
      workers = Integer(ENV.fetch('PARALLEL_TEST_PROCESSORS', 5))

      raise 'PARALLEL_TEST_PROCESSORS must be at least 1' if workers < 1

      puts 'Preparing test databases...'

      1.upto(workers) do |worker|
        test_env_number = worker == 1 ? '' : worker.to_s
        database_name = "tariff_test#{test_env_number}"
        env = {
          'RAILS_ENV' => 'test',
          'TEST_ENV_NUMBER' => test_env_number,
        }
        command = %w[bundle exec rails db:drop db:create db:structure:load]

        stdout, stderr, status = Open3.capture3(env, *command)

        if ENV['PARALLEL_TEST_PREPARE_VERBOSE'] == 'true'
          puts stdout
          warn stderr
        end

        unless status.success?
          puts stdout
          warn stderr
          abort "Failed to prepare #{database_name}"
        end

        puts "Prepared #{database_name}"
      end
    end
  end
end

if Rails.env.test?
  Rake::Task['db:structure:load'].enhance do
    Rake::Task['db:test:populate_empty_materialized_views'].invoke
  end
end

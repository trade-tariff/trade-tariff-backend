namespace :db do
  namespace :data do
    desc 'Set reporter class variable after the environment has loaded'
    task load_reporter: :environment do
      TradeTariffBackend::DataMigrator.reporter = TradeTariffBackend::DataMigrator::ConsoleReporter
    end

    desc 'Applies all pending data migrations'
    task migrate: :load_reporter do
      TradeTariffBackend::DataMigrator.migrate
    end

    desc 'Rollbacks last applied data migration'
    task rollback: :load_reporter do
      TradeTariffBackend::DataMigrator.rollback
    end

    desc 'Prints data migration application status'
    task status: :load_reporter do
      TradeTariffBackend::DataMigrator.status
    end

    desc 'Rollbacks last data migration and applies it'
    task redo: :load_reporter do
      TradeTariffBackend::DataMigrator.redo
    end

    desc 'Applies data migration one more time by timestamp'
    task :repeat, [:timestamp] => :load_reporter do |_task, args|
      TradeTariffBackend::DataMigrator.repeat(args[:timestamp])
    end

    desc 'Load old data migrations (run this task once)'
    task init_migrations_table: :load_reporter do
      TradeTariffBackend::DataMigrator.send(:migration_files).each do |file|
        next unless TradeTariffBackend::DataMigration::LogEntry.where(filename: file).none?

        l = TradeTariffBackend::DataMigration::LogEntry.new
        l.filename = file
        l.save
      end
    end
  end
end

require 'singleton'
require 'forwardable'

module TradeTariffBackend
  class DataMigrator
    autoload :ConsoleReporter, 'trade_tariff_backend/data_migrator/console_reporter'
    autoload :NullReporter,    'trade_tariff_backend/data_migrator/null_reporter'

    MIGRATION_FILE_PATTERN = /\A(\d+)_.+\.rb\z/i.freeze

    include Singleton
    extend SingleForwardable

    def_delegators :instance, :migrations, :migrations=,
                   :migrate, :migration, :rollback,
                   :status, :reporter=, :redo, :repeat

    attr_writer :migrations
    attr_writer :reporter

    def self.load_migration_files
      pending_migration_files.each { |file| load file }
    end

    # Define a new migration
    def migration(&block)
      @migrations ||= []

      TradeTariffBackend::DataMigration.new(&block).tap { |migration|
        @migrations << migration
      }
    end

    def report_with
      @reporter || NullReporter
    end

    # List of available migrations
    def migrations
      @migrations || []
    end

    # Migrates all pending migrations
    def migrate
      self.class.pending_migration_files.each do |file|
        # clear migrations array before loading
        @migrations = nil
        # load last migration for rollback
        load file
        # migration class will be loaded to @migrations
        migration = @migrations.last
        next unless migration

        # apply migration if can be rolled UP
        if migration.can_rollup?
          Sequel::Model.db.transaction(savepoint: true) {
            migration.up.apply
            report_with.applied(migration)
          }
        end
        # create log entry in data migrations table
        TradeTariffBackend::DataMigration::LogEntry.log!(file)
      end
    end

    # Rollsback last applied migration
    def rollback
      # get last applied migration
      entry = TradeTariffBackend::DataMigration::LogEntry.last
      return unless entry

      # clear migrations array before loading
      @migrations = nil
      # load last migration for rollback
      load entry.filename
      # migration class will be loaded to @migrations
      migration = @migrations.last
      return unless migration

      # apply migration if can be rolled DOWN
      if migration.can_rolldown?
        Sequel::Model.db.transaction(savepoint: true) {
          migration.down.apply
          report_with.rollback(migration)
        }
      end
      # destroy log entry from data migrations table
      entry.destroy
    end

    def redo
      rollback
      migrate
    end

    def repeat(timestamp)
      entry = TradeTariffBackend::DataMigration::LogEntry.where("filename LIKE '%#{timestamp}%'").last
      return unless entry

      # load migration
      load entry.filename
      # migration class will be loaded to @migrations
      migration = @migrations.last
      return unless migration

      # apply migration if can be rolled UP
      if migration.can_rollup?
        Sequel::Model.db.transaction(savepoint: true) {
          migration.up.apply
          report_with.applied(migration)
        }
      end
    end

    # Display data migration status
    def status
      migrations.each { |migration|
        report_with.status(migration)
      }
    end

  private

    def self.migration_files
      files = []
      directory = TradeTariffBackend.data_migration_path

      Dir.new(directory).each do |file|
        next unless MIGRATION_FILE_PATTERN.match(file)

        files << File.join(directory, file)
      end

      files.sort_by { |f|
        MIGRATION_FILE_PATTERN.match(File.basename(f))[1].to_i
      }
    end

    def self.pending_migration_files
      migration_files - TradeTariffBackend::DataMigration::LogEntry.all.map(&:filename)
    end
  end
end

# TradeTariffBackend::DataMigrator.load_migration_files unless Rails.env.test?

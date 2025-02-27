require 'rails/generators'

module Generators
  class DataMigrationGenerator < Rails::Generators::NamedBase
    class IllegalMigrationNameError < StandardError
      def initialize(name)
        super("Illegal name for migration file: #{name} (only lower case letters, numbers, and '_' allowed)")
      end
    end

    def create_data_migration_file
      validate_file_name!

      create_file data_migration_file_name, <<~EODATAMIGRATION
        Sequel.migration do
          # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
          # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked
          up do

          end

          down do

          end
        end
      EODATAMIGRATION
    end

    def data_migration_file_name
      "db/data_migrations/#{timestamp}_#{file_name}.rb"
    end

    def timestamp
      Time.zone.now.utc.strftime('%Y%m%d%H%M%S')
    end

    def validate_file_name!
      raise IllegalMigrationNameError, file_name unless /^[_a-z0-9]+$/.match?(file_name)
    end
  end
end

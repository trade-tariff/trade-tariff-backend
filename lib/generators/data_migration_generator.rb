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
        # IMPORTANT! Data migrations should be Idempotent, they may get re-run as part
        # of data rollbacks

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
    raise IllegalMigrationNameError, file_name unless file_name =~ /^[_a-z0-9]+$/
  end
end

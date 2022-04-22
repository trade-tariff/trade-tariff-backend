class DataMigrator < SequelRails::Migrations
  DATA_MIGRATIONS_TABLE = 'data_migrations'.freeze

  class << self
    def migrate(version = nil)
      opts = default_opts.dup
      opts[:target] = version.to_i if version

      if migrations_dir.directory?
        ::Sequel::Migrator.run(::Sequel::Model.db, migrations_dir, opts)
      else
        relative_path_name = migrations_dir.relative_path_from(Rails.root).to_s
        raise "The #{relative_path_name} directory doesn't exist, you need to create it."
      end
    end

    alias_method :migrate_up!, :migrate
    alias_method :migrate_down!, :migrate

    def pending_migrations?
      return false unless available_migrations?

      !::Sequel::Migrator.is_current?(::Sequel::Model.db, migrations_dir, default_opts)
    end

    def migrations_dir
      Rails.root.join('db/data_migrations')
    end

    def init_migrator
      migrator_class.new(::Sequel::Model.db, migrations_dir, default_opts)
    end

    private

    def default_opts
      ::Sequel::OPTS.merge(
        allow_missing_migration_files:,
        table: DATA_MIGRATIONS_TABLE,
      )
    end

    def migrator_class
      ::Sequel::TimestampMigrator
    end

    def allow_missing_migration_files
      !!SequelRails.configuration.allow_missing_migration_files
    end
  end
end

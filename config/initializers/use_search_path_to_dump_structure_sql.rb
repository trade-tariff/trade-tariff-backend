if Rails.env.development?
  # We have merged databases into 3 schemas (uk, xi, public)
  # but only the uk and public schemas are used in development and test Rails environments when performing migrations and dumping structure.sql.
  #
  # This patch avoids dumping the xi schema when producing the structure.sql file
  # which will only change after the local development postgres has been refreshed
  # with a dump from production and massively reduces noise during migrations.
  module SequelRails
    module Storage
      module PostgresDumpSchemas
        def _dump(filename)
          with_pgpassword do
            commands = %w[pg_dump]
            add_connection_settings commands
            add_flag commands, '-s'
            add_flag commands, '-x'
            add_flag commands, '-O'
            add_option commands, '--file', filename
            _add_schemas commands

            commands << database
            safe_exec commands
            _dump_extensions(filename)
          end
        end

        def _add_schemas(commands)
          search_path = Rails
                        .configuration
                        .database_configuration
                        .dig(Rails.env, 'search_path')
                        .to_s
                        .split(',')
                        .map(&:strip)

          if search_path.any?
            search_path.each do |schema|
              add_option commands, '--schema', schema
            end
          end
        end

        def _dump_extensions(filename)
          extension_file = 'db/extensions.sql'
          File.open(filename, 'a') do |file|
            file.write(File.read(extension_file))
          end
        end
      end
    end
  end

  SequelRails::Storage::Postgres.prepend(SequelRails::Storage::PostgresDumpSchemas)
end

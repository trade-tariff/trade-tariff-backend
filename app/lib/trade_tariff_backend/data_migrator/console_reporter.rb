require 'ansi/code'

module TradeTariffBackend
  class DataMigrator
    module ConsoleReporter
      module_function

      def status(migration)
        puts "[#{migration_state(migration)}] #{[migration.name, migration.desc].compact.join(": ")}"
      end

      def applied(migration)
        puts "[#{ANSI.green('applied'.upcase)}] #{migration.name}"
      end

      def rollback(migration)
        puts "[#{ANSI.red('rollback'.upcase)}] #{migration.name}"
      end

      def migration_state(migration)
        (migration.can_rollup?) ? ANSI.red('pending'.upcase) : ANSI.green('applied'.upcase)
      end
    end
  end
end

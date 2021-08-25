module TradeTariffBackend
  class DataMigration
    class Dependency
      def self.[](*migrations)
        new(migrations)
      end

      def initialize(migrations)
        @migrations = Array(migrations)
      end

      def applicable
        @migrations.all?(&:applicable)
      end

      alias :applicable? :applicable
    end
  end
end

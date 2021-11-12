module TradeTariffBackend
  class DataMigration
    class NullRunner < TradeTariffBackend::DataMigration::Runner
      def initialize(*)
        @applicable = -> { false }
        @apply = -> { false }

        super
      end
    end
  end
end

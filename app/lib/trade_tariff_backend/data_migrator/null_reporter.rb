module TradeTariffBackend
  class DataMigrator
    module NullReporter
      module_function

      def status(*)
        # noop
      end

      def applied(*)
        # noop
      end

      def rollback(*)
        # noop
      end
    end
  end
end

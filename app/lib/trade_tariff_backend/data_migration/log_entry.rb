module TradeTariffBackend
  class DataMigration
    class LogEntry < Sequel::Model(:data_migrations)
      def self.log!(file)
        l = new
        l.filename = file
        l.save
      end
    end
  end
end

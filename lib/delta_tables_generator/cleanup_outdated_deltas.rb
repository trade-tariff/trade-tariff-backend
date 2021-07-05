module DeltaTablesGenerator
  class CleanupOutdatedDeltas
    class << self
      DB = Sequel::Model.db

      def run(cleanup_older_than: Date.current.ago(3.months))
        DB[:deltas]
          .where('delta_date < ?', cleanup_older_than)
          .delete
      end
    end
  end
end

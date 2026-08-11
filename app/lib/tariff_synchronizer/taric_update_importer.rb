module TariffSynchronizer
  class TaricUpdateImporter
    def self.perform(taric_update)
      new(taric_update).import!
    end

    def initialize(taric_update)
      @taric_update = taric_update
    end

    def import!
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # Wrap the entire TARIC import in a single transaction so that all
      # TARIC-transaction records from one file are applied atomically — either
      # all land in the oplog tables or none do.  This mirrors the atomicity
      # that CdsUpdateImporter provides via StagingManager.
      Sequel::Model.db.transaction do
        @oplog_inserts = TaricImporter.new(@taric_update).import
      end

      store_oplog_inserts
      @taric_update.mark_as_applied

      duration_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000
      Instrumentation.file_import_completed(filename: @taric_update.filename, duration_ms:)
    end

  private

    def store_oplog_inserts
      @taric_update.inserts = @oplog_inserts.to_json
      @taric_update.save
    end
  end
end

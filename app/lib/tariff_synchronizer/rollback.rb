module TariffSynchronizer
  module Rollback
    def rollback_updates(update_type, rollback_date, keep: false)
      Rails.autoloaders.main.eager_load

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      TradeTariffBackend.with_redis_lock do
        TariffSynchronizer::Instrumentation.lock_acquired(phase: 'rollback')

        date = Date.parse(rollback_date.to_s)
        updates = update_type.where { issue_date > date }
        # Count before the transaction — updates may be deleted when keep is false.
        files_count = updates.count
        # TARIC deletes by operation_date; only CDS needs filenames in memory.
        update_filenames = update_type == TaricUpdate ? [] : updates.pluck(:filename)

        Sequel::Model.db.transaction do
          oplog_based_models.each do |model|
            delete_oplog_rows_for_rollback(model, update_type, update_filenames, date)
          end

          TariffChangesJobStatus.find(operation_date: date)&.mark_changes_pending!

          updates.each do |update|
            update.mark_as_pending
            update.clear_applied_at
            update.clear_errors
            update.delete unless keep
          end

          DataMigration.since(date.end_of_day).delete
        end

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        TariffSynchronizer::Instrumentation.rollback_completed(
          rollback_date: date.iso8601,
          duration_ms:,
          files_count:,
        )
      end
    rescue Redlock::LockError
      TariffSynchronizer::Instrumentation.lock_failed(phase: 'rollback')
    end

  private

    def oplog_based_models
      sequel_models.select do |model|
        model.plugins.include?(Sequel::Plugins::Oplog)
      end
    end

    # CDS stamps filename on oplog inserts and rolls back by filename.
    # TARIC does not populate filename; roll back by operation_date (indexed).
    def delete_oplog_rows_for_rollback(model, update_type, update_filenames, date)
      dataset = model.operation_klass

      if update_type == TaricUpdate
        dataset.where(Sequel[:operation_date] > date).delete
      else
        dataset.where(filename: update_filenames).delete
      end
    end
  end
end

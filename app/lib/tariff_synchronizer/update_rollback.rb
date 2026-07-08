module TariffSynchronizer
  module UpdateRollback
    def rollback_updates(update_type, rollback_date, keep: false)
      Rails.autoloaders.main.eager_load

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      TradeTariffBackend.with_redis_lock do
        TariffSynchronizer::Instrumentation.lock_acquired(phase: 'rollback')

        date = Date.parse(rollback_date.to_s)
        updates = update_type.where { issue_date > date }
        update_filenames = updates.pluck(:filename)

        Sequel::Model.db.transaction do
          oplog_based_models.each do |model|
            model.operation_klass
                 .where(filename: update_filenames)
                 .delete
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
          files_count: update_filenames.size,
        )
      end
    rescue Redlock::LockError
      TariffSynchronizer::Instrumentation.lock_failed(phase: 'rollback')
    end
  end
end

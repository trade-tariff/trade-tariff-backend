module TariffSynchronizer
  module UpdateApplication
    def apply_updates(update_type)
      applied_updates = []
      import_warnings = []

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      TradeTariffBackend.with_redis_lock do
        TariffSynchronizer::Instrumentation.lock_acquired(phase: 'apply')

        check_tariff_updates_failures
        check_sequence

        sequel_models.each(&:unrestrict_primary_key)

        subscribe 'apply.import_warnings' do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          import_warnings << event.payload
        end

        date_range = date_range_since_oldest_pending_update
        date_range.each do |day|
          applied_updates << perform_update(update_type, day)
        end

        applied_updates.flatten!

        if applied_updates.any? && BaseUpdate.pending_or_failed.none?
          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
          TariffSynchronizer::Instrumentation.apply_completed(
            duration_ms:,
            files_applied: applied_updates.size,
          )
          TariffLogger.apply(applied_updates.map(&:filename), import_warnings)
          true
        end
      end
    rescue Redlock::LockError
      TariffSynchronizer::Instrumentation.lock_failed(phase: 'apply')
    end

    def date_range_since_oldest_pending_update
      oldest_pending_update = BaseUpdate.oldest_pending
      return [] if oldest_pending_update.blank?

      (oldest_pending_update.issue_date..update_to)
    end

    def perform_update(update_type, day)
      updates = update_type.pending_at(day).to_a
      updates.map do |update|
        Instrumentation.file_import_started(filename: update.filename)

        BaseUpdateImporter.perform(update)
      end
      updates
    end
  end
end

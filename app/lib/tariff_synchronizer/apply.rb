module TariffSynchronizer
  # The day-by-day half of TariffSynchronizer#apply_updates, kept here for the
  # same reason Rollback is: to keep the host module readable.
  module Apply
    # Applies each pending day in order, stopping at the first day that fails. A
    # failed update leaves a hole in the oplog sequence: later days' UPDATE and
    # DELETE rows expect the skipped day's inserts, so applying them corrupts data.
    def apply_each_pending_day(update_type)
      applied_updates = []

      date_range_since_oldest_pending_update.each do |day|
        updates = perform_update(update_type, day)
        applied_updates.concat(updates)

        failed_updates = updates.select(&:failed?)
        next if failed_updates.none?

        Instrumentation.apply_aborted(filenames: failed_updates.map(&:filename))
        break
      end

      applied_updates
    end

    def date_range_since_oldest_pending_update
      oldest_pending_update = BaseUpdate.oldest_pending
      return [] if oldest_pending_update.blank?

      (oldest_pending_update.issue_date..update_to)
    end

    def perform_update(update_type, day)
      updates = update_type.pending_at(day).to_a
      updates.each do |update|
        Instrumentation.file_import_started(filename: update.filename)
        BaseUpdateImporter.perform(update)
      end
    end
  end
end

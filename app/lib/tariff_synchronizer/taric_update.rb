module TariffSynchronizer
  class TaricUpdate < BaseUpdate
    NEW_YEAR_STARTING_SEQUENCE_NUMBER = 1
    REGEX_TARIC_SEQUENCE = /^\d{4}-\d{2}-\d{2}_(?<url_filename>TGB(?<year>\d{2})(?<sequence>\d+).xml)$/
    SEQUENCE_APPLICABLE_UPDATE_LIMIT = 10
    SEQUENCE_APPLICABLE_STATES = [APPLIED_STATE, PENDING_STATE].freeze

    class << self
      def sync(initial_date:)
        applicable_download_date_range(initial_date:).each { |issue_date| download(issue_date) }
      end

      def sync_patched
        TaricUpdateDownloaderPatched.new(applicable_update).perform
      end

      def download(issue_date)
        TaricUpdateDownloader.new(issue_date).perform
      end

      # Validates the last n of updates are in the correct sequence in order to know whether we're safe to apply pending updates. Out of order updates happen when the Taric api publishes files later than the date they're meant to be downloaded and should halt the applying of the update process.
      def correct_filename_sequence?
        sequence_applicable_updates.each_cons(2) do |next_update, previous_update|
          return false unless correct_sequence_pair?(next_update, previous_update)
        end

        true
      end

      def correct_sequence_pair?(next_update, previous_update)
        next_sequence = next_update.filename_sequence
        previous_sequence = previous_update.filename_sequence

        previous_year = previous_sequence[:year].to_i
        next_year = next_sequence[:year].to_i

        expected_next_sequence = if previous_year == next_year
                                   previous_sequence[:sequence].to_i + 1
                                 else
                                   NEW_YEAR_STARTING_SEQUENCE_NUMBER
                                 end

        next_sequence[:sequence].to_i == expected_next_sequence
      end

      def update_type
        :taric
      end

      def applicable_update
        # Pull out the most recent update
        current_update = most_recent_pending || most_recent_applied

        # Bail if there isn't one (impossible from where the data is now)
        return nil if current_update.blank?
        # Bail if we need to correct with a manual rollback
        return nil unless correct_filename_sequence?

        current_update.next_update
      end

      private

      def sequence_applicable_updates
        descending.where(state: SEQUENCE_APPLICABLE_STATES).limit(SEQUENCE_APPLICABLE_UPDATE_LIMIT)
      end
    end

    def to_param
      filename.sub('.xml', '')
    end

    def import!
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      @oplog_inserts = TaricImporter.new(self).import

      mark_as_applied
      store_oplog_inserts

      duration_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000
      Instrumentation.file_import_completed(filename:, duration_ms:)
    end

    def filename_sequence
      filename.match(REGEX_TARIC_SEQUENCE)
    end

    def next_update
      self.class.new(
        filename: next_update_sequence_update_filename,
        issue_date: next_update_issue_date,
      )
    end

    def next_rollover_update
      self.class.new(
        filename: next_update_sequence_rollover_update_filename,
        issue_date: next_update_rollover_issue_date,
      )
    end

    def next_update_sequence_update_filename
      "#{next_update_issue_date.iso8601}_#{next_update_sequence_url_filename}"
    end

    def next_update_sequence_rollover_update_filename
      "#{next_update_rollover_issue_date.iso8601}_#{next_update_sequence_rollover_url_filename}"
    end

    def next_update_sequence_url_filename
      padded_sequence = next_update_sequence.to_s.rjust(3, '0')
      year = next_update_issue_date.strftime('%y')

      "TGB#{year}#{padded_sequence}.xml"
    end

    def next_update_sequence_rollover_url_filename
      padded_sequence = NEW_YEAR_STARTING_SEQUENCE_NUMBER.to_s.rjust(3, '0')
      year = next_update_rollover_issue_date.strftime('%y')

      "TGB#{year}#{padded_sequence}.xml"
    end

    def url_filename
      filename_sequence[:url_filename]
    end

    def sequence_increment
      filename_sequence[:sequence].to_i
    end

    def next_update_sequence
      issue_date.year == next_update_year ? sequence_increment + 1 : NEW_YEAR_STARTING_SEQUENCE_NUMBER
    end

    def next_update_issue_date
      issue_date + 1.day
    end

    def next_update_rollover_issue_date
      (issue_date + 1.year).beginning_of_year
    end

    def next_update_year
      next_update_issue_date.year
    end

    def store_oplog_inserts
      # self.inserts = @oplog_inserts.to_json

      save
    end
  end
end

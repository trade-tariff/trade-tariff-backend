module TariffSynchronizer
  class TaricUpdate < BaseUpdate
    NEW_YEAR_STARTING_SEQUENCE_NUMBER = 1
    REGEX_TARIC_SEQUENCE = /^\d{4}-\d{2}-\d{2}_TGB(?<year>\d{2})(?<sequence>\d+).xml$/
    SEQUENCE_APPLICABLE_UPDATE_LIMIT = 10
    SEQUENCE_APPLICABLE_STATES = [APPLIED_STATE, PENDING_STATE].freeze

    class << self
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

      def download(date)
        TaricUpdateDownloader.new(date).perform
      end

      def update_type
        :taric
      end

      private

      def sequence_applicable_updates
        descending.where(state: SEQUENCE_APPLICABLE_STATES).limit(SEQUENCE_APPLICABLE_UPDATE_LIMIT)
      end
    end

    def import!
      instrument('apply_taric.tariff_synchronizer', filename: filename) do
        TaricImporter.new(self).import
        mark_as_applied
      end
    end

    def filename_sequence
      filename.match(REGEX_TARIC_SEQUENCE)
    end

    def self.validate_file!(xml_string)
      Ox.parse(xml_string)
    rescue Ox::ParseError => e
      raise InvalidContents.new(e.message, e)
    end
  end
end

module TariffSynchronizer
  class TaricUpdate < BaseUpdate
    REGEX_TARIC_SEQUENCE = /^\d{4}-\d{2}-\d{2}_TGB(?<year>\d{2})(?<sequence>\d+).xml$/
    NEW_YEAR_STARTING_SEQUENCE_NUMBER = 1

    class << self
      def correct_filename_sequence?
        pending_seq = last_pending&.filename_sequence
        applied_seq = last_applied&.filename_sequence

        return true if pending_seq.blank? || applied_seq.blank?

        current_sequence_number = pending_seq[:sequence].to_i

        expected_new_sequence_number = if pending_seq[:year].to_i == applied_seq[:year].to_i
                                         applied_seq[:sequence].to_i + 1
                                       else
                                         NEW_YEAR_STARTING_SEQUENCE_NUMBER
                                       end

        current_sequence_number == expected_new_sequence_number
      end

      def download(date)
        TaricUpdateDownloader.new(date).perform
      end

      def update_type
        :taric
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

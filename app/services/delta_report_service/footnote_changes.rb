class DeltaReportService
  class FootnoteChanges < BaseChanges
    def self.collect(date)
      Footnote
        .where(operation_date: date)
        .order(:oid)
        .map { |record| new(record, date).analyze }
        .compact
    end

    def object_name
      'Footnote'
    end

    def excluded_columns
      super + %i[national]
    end

    def analyze
      return if no_changes?

      TimeMachine.at(record.validity_start_date) do
        {
          type: 'Footnote',
          footnote_oid: record.oid,
          description:,
          date_of_effect:,
          change: change.present? ? "#{record.code}: #{change}" : "#{record.code}: #{record.description}",
        }
      end
    rescue StandardError => e
      Rails.logger.error "Error with #{object_name} OID #{record.oid}"
      raise e
    end
  end
end

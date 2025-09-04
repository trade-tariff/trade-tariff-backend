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

      {
        type: 'Footnote',
        footnote_oid: record.oid,
        description:,
        date_of_effect:,
        change: change.present? ? "#{record.code}: #{change}" : record.code,
      }
    end
  end
end

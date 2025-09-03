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

    def previous_record
      @previous_record ||= Footnote.operation_klass
                             .where(footnote_id: record.footnote_id, footnote_type_id: record.footnote_type_id)
                             .where(Sequel.lit('oid < ?', record.oid))
                             .order(Sequel.desc(:oid))
                             .first
    end
  end
end

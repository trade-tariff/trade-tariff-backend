class DeltaReportService
  class AdditionalCodeChanges < BaseChanges
    include MeasurePresenter

    def self.collect(date)
      AdditionalCode
        .where(operation_date: date)
        .order(:oid)
        .map { |record| new(record, date).analyze }
        .compact
    end

    def object_name
      'Additional Code'
    end

    def analyze
      return if no_changes?

      {
        type: 'AdditionalCode',
        additional_code_sid: record.additional_code_sid,
        additional_code: additional_code(record),
        description:,
        date_of_effect:,
        change: change || '',
      }
    rescue StandardError => e
      Rails.logger.error "Error with #{object_name} OID #{record.oid}"
      raise e
    end
  end
end

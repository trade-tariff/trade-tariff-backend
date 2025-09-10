class DeltaReportService
  class CertificateChanges < BaseChanges
    include MeasurePresenter

    def self.collect(date)
      Certificate
        .where(operation_date: date)
        .order(:oid)
        .map { |record| new(record, date).analyze }
        .compact
    end

    def object_name
      'Certificate'
    end

    def analyze
      return if no_changes?

      TimeMachine.at(record.validity_start_date) do
        {
          type: 'Certificate',
          certificate_type_code: record.certificate_type_code,
          certificate_code: record.certificate_code,
          date_of_effect:,
          description:,
          change: change || record.id,
        }
      end
    rescue StandardError => e
      Rails.logger.error "Error with #{object_name} OID #{record.oid}"
      raise e
    end
  end
end

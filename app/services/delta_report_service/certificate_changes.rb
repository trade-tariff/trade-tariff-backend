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
      return if record.operation == :update && changes.empty?

      {
        type: 'Certificate',
        certificate_type_code: record.certificate_type_code,
        certificate_code: record.certificate_code,
        date_of_effect:,
        description:,
        change: change || record.id,
      }
    end

    def previous_record
      @previous_record ||= Certificate.operation_klass
                             .where(certificate_code: record.certificate_code, certificate_type_code: record.certificate_type_code)
                             .where(Sequel.lit('oid < ?', record.oid))
                             .order(Sequel.desc(:oid))
                             .first
    end
  end
end

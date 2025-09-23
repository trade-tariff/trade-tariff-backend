class DeltaReportService
  class QuotaEventChanges < BaseChanges
    def self.collect(date)
      events = {
        'Exhausted' => QuotaExhaustionEvent,
        'Critical' => QuotaCriticalEvent,
      }

      events.each_with_object([]) do |(status, model), arr|
        arr.concat(
          model.where(operation_date: date)
               .map { |record| new(record, date).analyze(status) }
               .compact,
        )
      end
    end

    def object_name
      'Quota Event'
    end

    def analyze(status)
      {
        type: 'QuotaEvent',
        quota_definition_sid: record.quota_definition_sid,
        date_of_effect: date_of_effect,
        description: "Quota Status: #{status}",
      }
    rescue StandardError => e
      Rails.logger.error "Error with #{object_name} OID #{record.oid}"
      raise e
    end

    def date_of_effect
      date
    end
  end
end

class DeltaReportService
  class QuotaEventChanges < BaseChanges
    def self.collect(date)
      event_models = [QuotaExhaustionEvent, QuotaCriticalEvent]

      events = event_models.each_with_object([]) { |model, arr|
        model.where(operation_date: date).each do |event|
          arr << event.quota_definition_sid
        end
      }.uniq

      events.map { |sid|
        record = QuotaDefinition.first(quota_definition_sid: sid)
        new(record, date).analyze
      }.compact
    end

    def object_name
      'Quota Event'
    end

    def analyze
      status = record.status

      return unless status.in?(%w[Exhausted Critical])

      TimeMachine.at(date - 1.day) do
        previous = QuotaDefinition.first(quota_definition_sid: record.quota_definition_sid)
        return if status == previous.status
      end

      {
        type: 'QuotaEvent',
        quota_definition_sid: record.quota_definition_sid,
        date_of_effect: date_of_effect,
        description: "Quota Status: #{status}",
        change: change,
      }
    rescue StandardError => e
      Rails.logger.error "Error with #{object_name} SID #{record.quota_definition_sid}"
      raise e
    end

    def change
      if record.status == 'Exhausted'
        'Quota Exhausted'
      else
        "Balance: #{TradeTariffBackend.number_formatter.number_with_precision(record.balance, precision: 3, delimiter: ',')} #{record.measurement_unit}"
      end
    end

    def date_of_effect
      date
    end
  end
end

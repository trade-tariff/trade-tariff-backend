class QuotaUtilizationPresenter
  attr_reader :quota_order_number, :quota_definition, :balance_events, :from_date, :to_date

  delegate :quota_order_number_id, to: :quota_order_number

  delegate :quota_definition_sid,
           :validity_start_date,
           :validity_end_date,
           :initial_volume,
           :status,
           :measurement_unit_code,
           :quota_type,
           to: :quota_definition

  def initialize(quota_order_number, quota_definition, balance_events, from_date, to_date)
    @quota_order_number = quota_order_number
    @quota_definition = quota_definition
    @balance_events = balance_events
    @from_date = from_date
    @to_date = to_date
  end

  def id
    "#{quota_order_number.quota_order_number_id}-#{quota_definition.quota_definition_sid}"
  end

  def current_balance
    quota_definition.balance
  end

  def volume_used
    return 0.0 if initial_volume.nil?

    [initial_volume - current_balance, 0.0].max
  end

  def utilization_percentage
    return 0.0 if initial_volume.nil? || initial_volume.zero?

    (volume_used / initial_volume * 100).round(2)
  end

  def balance_event_summary
    balance_events.map do |event|
      {
        occurrence_timestamp: event.occurrence_timestamp,
        new_balance: event.new_balance,
      }
    end
  end
end

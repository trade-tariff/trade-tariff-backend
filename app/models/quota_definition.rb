class QuotaDefinition < Sequel::Model
  DEFINITION_CRITICAL_STATE = 'Y'.freeze

  plugin :time_machine
  plugin :oplog, primary_key: :quota_definition_sid

  set_primary_key [:quota_definition_sid]

  one_to_one :quota_order_number, key: :quota_order_number_sid,
                                  primary_key: :quota_order_number_sid

  one_to_many :quota_critical_events, key: :quota_definition_sid do |ds|
    ds
      .where('occurrence_timestamp <= ?', point_in_time)
      .order(Sequel.desc(:occurrence_timestamp))
  end

  one_to_many :quota_exhaustion_events, key: :quota_definition_sid,
                                        primary_key: :quota_definition_sid

  one_to_one :incoming_quota_closed_and_transferred_event, class_name: 'QuotaClosedAndTransferredEvent',
                                                           key: :target_quota_definition_sid,
                                                           primary_key: :quota_definition_sid do |ds|
    if point_in_time
      # Quota transfers become visible when the closing date of the previous definition has come to pass
      ds.where('closing_date < ?', point_in_time.to_date)
    else
      ds
    end
  end

  delegate :id, to: :incoming_quota_closed_and_transferred_event, prefix: true, allow_nil: true

  one_to_one :outgoing_quota_closed_and_transferred_events, class_name: 'QuotaClosedAndTransferredEvent',
                                                            key: :quota_definition_sid,
                                                            primary_key: :quota_definition_sid
  one_to_many :quota_balance_events,
              key: :quota_definition_sid,
              primary_key: :quota_definition_sid

  one_to_many :quota_suspension_periods, key: :quota_definition_sid,
                                         primary_key: :quota_definition_sid do |ds|
    ds.with_actual(QuotaSuspensionPeriod)
  end

  one_to_many :quota_blocking_periods, key: :quota_definition_sid,
                                       primary_key: :quota_definition_sid do |ds|
    ds.with_actual(QuotaBlockingPeriod)
  end

  one_to_one :measurement_unit, primary_key: :measurement_unit_code,
                                key: :measurement_unit_code do |ds|
    ds.with_actual(MeasurementUnit)
  end

  one_to_many :measures, key: [:ordernumber],
                         primary_key: [:quota_order_number_id] do |ds|
    ds.where('validity_end_date IS NULL OR validity_end_date >= ?', Measure.point_in_time)
  end

  def measure_ids
    measures&.map(&:measure_sid)
  end

  def quota_balance_event_ids
    quota_balance_events&.map(&:id)
  end

  delegate :description, :abbreviation, to: :measurement_unit, prefix: true, allow_nil: true

  def formatted_measurement_unit
    "#{measurement_unit_description} (#{measurement_unit_abbreviation})" if measurement_unit_description.present?
  end

  # TODO: There is a cascading logic to the status that events set.
  #
  #       Status (pending a discussion) should be determined by active events and be prioritised in the following order:
  #
  #       - suspended
  #       - blocked
  #       - exhausted
  #       - critical
  #       - open events
  #
  #       We've explicitly excluded the QuotaClosedAndTransferredEvent since this event isn't relevant
  #       to the quota definition that we're transferring a balance from.
  def status
    if last_event.present?
      return QuotaCriticalEvent.status if has_active_critical_event?

      last_event.status
    else
      critical_state? ? QuotaCriticalEvent.status : QuotaBalanceEvent.status
    end
  end

  def last_event
    @last_event ||= QuotaEvent.last_for(quota_definition_sid, point_in_time)
  end

  def last_balance_event
    @last_balance_event ||= quota_balance_events.select { |quota_balance_event|
      point_in_time.blank? || quota_balance_event.occurrence_timestamp <= point_in_time
    }.max_by(&:occurrence_timestamp)
  end

  def balance
    last_balance_event.present? ? last_balance_event.new_balance : initial_volume
  end

  def last_suspension_period
    @last_suspension_period ||= quota_suspension_periods.last
  end

  def last_blocking_period
    @last_blocking_period ||= quota_blocking_periods.last
  end

private

  # We only care about Open, Exhausted and Critical statuses from a UI perspective
  def has_active_critical_event?
    last_event.status == QuotaBalanceEvent.status && last_critical_event&.active?
  end

  def last_critical_event
    @last_critical_event ||= quota_critical_events.first
  end

  def critical_state?
    critical_state == DEFINITION_CRITICAL_STATE
  end
end

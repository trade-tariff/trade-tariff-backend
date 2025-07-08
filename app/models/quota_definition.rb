class QuotaDefinition < Sequel::Model
  DATE_HMRC_STARTED_MANAGING_PENDING_BALANCES = Date.parse('2022-07-01').freeze
  DEFINITION_CRITICAL_STATE = 'Y'.freeze

  plugin :time_machine
  plugin :oplog, primary_key: :quota_definition_sid, materialized: true

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

  one_to_many :quota_unsuspension_events, key: :quota_definition_sid,
                                          primary_key: :quota_definition_sid

  one_to_many :quota_unblocking_events, key: :quota_definition_sid,
                                        primary_key: :quota_definition_sid

  one_to_many :quota_reopening_events, key: :quota_definition_sid,
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
              primary_key: :quota_definition_sid,
              order: Sequel.desc(:occurrence_timestamp)

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

  one_to_many :measures, key: :ordernumber,
                         primary_key: :quota_order_number_id do |ds|
    ds.where('validity_end_date IS NULL OR validity_end_date >= ?', Measure.point_in_time)
  end

  dataset_module do
    def excluding_licensed_quotas
      exclusion_criteria = Sequel.|(
        *QuotaOrderNumber::LICENSED_QUOTA_PREFIXES.map do |prefix|
          Sequel.like(:quota_order_number_id, "#{prefix}%")
        end,
      )

      exclude(exclusion_criteria)
    end
  end

  def measure_ids
    measures&.map(&:measure_sid)
  end

  def quota_balance_event_ids
    quota_balance_events&.map(&:id)
  end

  delegate :description, :abbreviation, to: :measurement_unit, prefix: true, allow_nil: true

  def measurement_unit_id
    measurement_unit_code
  end

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
    return QuotaExhaustionEvent.status if has_exhausted_event?

    if suspension_period_active?
      QuotaSuspensionPeriod.status
    elsif blocking_period_active?
      QuotaBlockingPeriod.status
    elsif last_event.present?
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

  def shows_balance_transfers?
    validity_start_date.to_date >= DATE_HMRC_STARTED_MANAGING_PENDING_BALANCES
  end

  def quota_type
    quota_order_number_id[2] == '4' ? 'Licensed' : 'First Come First Served'
  end

  def quota_order_number_origin_ids
    quota_order_number_origins&.pluck(:id)
  end

  delegate :quota_order_number_origins, to: :quota_order_number, allow_nil: true

  def quota_unsuspension_event_ids
    quota_unsuspension_events&.map(&:quota_definition_sid)
  end

  def quota_reopening_event_ids
    quota_reopening_events&.map(&:quota_definition_sid)
  end

  def quota_unblocking_event_ids
    quota_unblocking_events&.map(&:quota_definition_sid)
  end

  def quota_exhaustion_event_ids
    quota_exhaustion_events&.map(&:quota_definition_sid)
  end

  def quota_critical_event_ids
    quota_critical_events&.map(&:quota_definition_sid)
  end

  private

  def suspension_period_active?
    if last_suspension_period.present?
      today = Time.zone.today

      true if today >= last_suspension_period.suspension_start_date && today <= last_suspension_period.suspension_end_date
    end
  end

  def blocking_period_active?
    if last_blocking_period.present?
      today = Time.zone.today

      true if today >= last_blocking_period.blocking_start_date && today <= last_blocking_period.blocking_end_date
    end
  end

  # We only care about Open, Exhausted and Critical statuses from a UI perspective
  def has_active_critical_event?
    last_event.status == QuotaBalanceEvent.status && last_critical_event&.active?
  end

  def has_exhausted_event?
    last_event.status == QuotaExhaustionEvent.status
  end

  def last_critical_event
    @last_critical_event ||= quota_critical_events.first
  end

  def critical_state?
    critical_state == DEFINITION_CRITICAL_STATE
  end
end

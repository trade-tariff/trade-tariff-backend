# Builds the SQL expression that computes quota status precedence for a
# single quota definition row.
class QuotaStatusSql
  OPEN_EVENT_TYPES = %w[balance reopening unblocking unsuspension].freeze

  Fragment = Struct.new(:str, :args)

  def initialize(definition_table:, point_in_time:)
    @definition_table = definition_table.to_s
    @point_in_time = point_in_time
  end

  def to_fragment
    latest_event_type = latest_event_type_sql
    latest_critical_state = latest_critical_state_sql
    suspended = active_suspension_sql
    blocked = active_blocking_sql

    sql = <<~SQL
      CASE
        WHEN (#{latest_event_type}) = 'exhaustion' THEN '#{QuotaDefinition::STATUS_EXHAUSTED}'
        WHEN #{suspended.str} THEN '#{QuotaDefinition::STATUS_SUSPENDED}'
        WHEN #{blocked.str} THEN '#{QuotaDefinition::STATUS_BLOCKED}'
        WHEN (#{latest_event_type}) = 'critical' THEN '#{QuotaDefinition::STATUS_CRITICAL}'
        WHEN (#{latest_event_type}) IN (#{open_event_types_sql})
          AND (#{latest_critical_state.str}) = '#{QuotaCriticalEvent::ACTIVE_CRITICAL_STATE}' THEN '#{QuotaDefinition::STATUS_CRITICAL}'
        WHEN (#{latest_event_type}) IS NOT NULL THEN '#{QuotaDefinition::STATUS_OPEN}'
        ELSE CASE
               WHEN "#{definition_table}"."critical_state" = '#{QuotaDefinition::DEFINITION_CRITICAL_STATE}' THEN '#{QuotaDefinition::STATUS_CRITICAL}'
               ELSE '#{QuotaDefinition::STATUS_OPEN}'
             END
      END
    SQL

    Fragment.new(sql, suspended.args + blocked.args + latest_critical_state.args)
  end

private

  attr_reader :definition_table, :point_in_time

  def latest_event_type_sql
    QuotaEvent.latest_event_type_dataset(
      Sequel[definition_table.to_sym][:quota_definition_sid],
      point_in_time,
    ).sql
  end

  def latest_critical_state_sql
    Fragment.new(
      <<~SQL,
        SELECT "quota_critical_events"."critical_state"
          FROM "quota_critical_events"
         WHERE "quota_critical_events"."quota_definition_sid" = "#{definition_table}"."quota_definition_sid"
           AND "quota_critical_events"."occurrence_timestamp" <= ?
         ORDER BY "quota_critical_events"."occurrence_timestamp" DESC
         LIMIT 1
      SQL
      [point_in_time],
    )
  end

  def active_suspension_sql
    Fragment.new(
      <<~SQL,
        EXISTS (
          SELECT 1
            FROM "quota_suspension_periods"
           WHERE "quota_suspension_periods"."quota_definition_sid" = "#{definition_table}"."quota_definition_sid"
             AND ("quota_suspension_periods"."suspension_start_date" <= ?
             AND ("quota_suspension_periods"."suspension_end_date" >= ?
             OR "quota_suspension_periods"."suspension_end_date" IS NULL))
           LIMIT 1
        )
      SQL
      [point_in_time, point_in_time],
    )
  end

  def active_blocking_sql
    Fragment.new(
      <<~SQL,
        EXISTS (
          SELECT 1
            FROM "quota_blocking_periods"
           WHERE "quota_blocking_periods"."quota_definition_sid" = "#{definition_table}"."quota_definition_sid"
             AND ("quota_blocking_periods"."blocking_start_date" <= ?
             AND ("quota_blocking_periods"."blocking_end_date" >= ?
             OR "quota_blocking_periods"."blocking_end_date" IS NULL))
           LIMIT 1
        )
      SQL
      [point_in_time, point_in_time],
    )
  end

  def open_event_types_sql
    OPEN_EVENT_TYPES.map { |event_type| "'#{event_type}'" }.join(', ')
  end
end

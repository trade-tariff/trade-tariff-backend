# Builds the filtered dataset of Measures used to look up quota definitions.

class QuotaDefinitionsQuery
  STATUS_VALUES = %w[blocked exhausted not_blocked not_exhausted suspended not_suspended open].freeze

  class InvalidStatus < StandardError; end

  attr_reader :goods_nomenclature_item_id, :geographical_area_id, :order_number,
              :critical, :status, :date

  def initialize(attributes, date)
    status_value = attributes['status']&.gsub(/[+ ]/, '_')
    if status_value.present? && STATUS_VALUES.exclude?(status_value)
      raise InvalidStatus, "invalid status: #{attributes['status']}"
    end

    @status = ActiveSupport::StringInquirer.new(status_value || '')
    @goods_nomenclature_item_id = attributes['goods_nomenclature_item_id']
    @geographical_area_id = attributes['geographical_area_id']
    @order_number = attributes['order_number']
    @critical = attributes['critical']
    @date = date
  end

  def eager_quota_exhaustion_events?
    status.exhausted? || status.not_exhausted?
  end

  def apply(scope)
    scope = apply_quota_definition_filter(scope)
    scope = apply_goods_nomenclature_item_id_filter(scope) if goods_nomenclature_item_id.present?
    scope = apply_geographical_area_id_filter(scope) if geographical_area_id.present?
    scope = apply_order_number_filter(scope) if order_number.present?

    scope
  end

private

  def apply_goods_nomenclature_item_id_filter(scope)
    ancestors = FindAncestorsService.new(goods_nomenclature_item_id).call

    if ancestors.present?
      scope.where(goods_nomenclature_item_id: ancestors)
    else
      scope.where(Sequel.like(:measures__goods_nomenclature_item_id, "#{goods_nomenclature_item_id}%"))
    end
  end

  def apply_geographical_area_id_filter(scope)
    geographical_area_ids = GeographicalArea.where(geographical_area_id:).actual.take.included_geographical_areas.pluck(:geographical_area_id)
    geographical_area_ids << geographical_area_id

    scope.where(measures__geographical_area_id: geographical_area_ids)
  end

  def apply_order_number_filter(scope)
    scope.where(measures__ordernumber: order_number)
  end

  def apply_quota_definition_filter(scope)
    critical_condition = critical.present? ? 'AND quota_definitions."critical_state" = \'Y\'' : ''
    args = [date, date]
    if status.present?
      status_filter = send("apply_#{status}_filter")
      status_condition = "AND #{status_filter.str}"
      args.push(*status_filter.args)
    end

    sql = Sequel.lit(
      <<~SQL, *args
        EXISTS (
          SELECT 1
          FROM "quota_definitions" quota_definitions
          WHERE quota_definitions."quota_order_number_id" = "measures"."ordernumber"
            AND quota_definitions."validity_start_date" <= ?
            AND (quota_definitions."validity_end_date" >= ? OR quota_definitions."validity_end_date" IS NULL)
            #{critical_condition}
            #{status_condition}
          LIMIT 1
        )
      SQL
    )

    scope.where(sql)
  end

  # QuotaDefinition#status considers a quota "Exhausted" only when the most
  # recent quota event (across all event types - exhaustion, balance,
  # critical, reopening, unblocking, unsuspension) is an exhaustion event
  # (see QuotaEvent.last_for / QuotaDefinition#has_exhausted_event?). A
  # historical exhaustion event that has since been superseded by a newer
  # reopening or balance event must NOT be treated as exhausted, so we
  # replicate that "latest event wins" semantics here rather than just
  # checking whether an exhaustion event exists at all.
  def latest_quota_event_type_sql
    unions = QuotaEvent::EVENTS.map { |event_type|
      table = "quota_#{event_type}_events"

      <<~SQL
        SELECT '#{event_type}' AS event_type, "#{table}"."occurrence_timestamp"
          FROM "#{table}"
         WHERE "#{table}"."quota_definition_sid" = "quota_definitions"."quota_definition_sid"
           AND "#{table}"."occurrence_timestamp" <= ?
      SQL
    }.join("UNION ALL\n")

    Sequel.lit(
      <<~SQL, *([QuotaDefinition.point_in_time] * QuotaEvent::EVENTS.length)
        (
          SELECT event_type
            FROM (
              #{unions}
            ) latest_quota_events
           ORDER BY occurrence_timestamp DESC, event_type DESC
           LIMIT 1
        )
      SQL
    )
  end

  def apply_exhausted_filter
    latest_event_type = latest_quota_event_type_sql

    Sequel.lit("#{latest_event_type.str} = 'exhaustion'", *latest_event_type.args)
  end

  def apply_not_exhausted_filter
    latest_event_type = latest_quota_event_type_sql

    Sequel.lit("#{latest_event_type.str} IS DISTINCT FROM 'exhaustion'", *latest_event_type.args)
  end

  def apply_blocked_filter
    Sequel.lit(
      <<~SQL, QuotaDefinition.point_in_time, QuotaDefinition.point_in_time
        EXISTS (
        SELECT *
          FROM "quota_blocking_periods"
         WHERE "quota_blocking_periods"."quota_definition_sid" = "quota_definitions"."quota_definition_sid" AND
               ("quota_blocking_periods"."blocking_start_date" <= ? AND
               ("quota_blocking_periods"."blocking_end_date" >= ? OR
                "quota_blocking_periods"."blocking_end_date" IS NULL))
         LIMIT 1
        )
      SQL
    )
  end

  def apply_not_blocked_filter
    Sequel.lit(
      <<~SQL, QuotaDefinition.point_in_time, QuotaDefinition.point_in_time
        NOT EXISTS (
        SELECT *
          FROM "quota_blocking_periods"
         WHERE "quota_blocking_periods"."quota_definition_sid" = "quota_definitions"."quota_definition_sid" AND
               ("quota_blocking_periods"."blocking_start_date" <= ? AND
               ("quota_blocking_periods"."blocking_end_date" >= ? OR
                "quota_blocking_periods"."blocking_end_date" IS NULL))
         LIMIT 1
        )
      SQL
    )
  end

  def apply_suspended_filter
    Sequel.lit(
      <<~SQL, QuotaDefinition.point_in_time, QuotaDefinition.point_in_time
        EXISTS (
        SELECT *
          FROM "quota_suspension_periods"
         WHERE "quota_suspension_periods"."quota_definition_sid" = "quota_definitions"."quota_definition_sid" AND
               ("quota_suspension_periods"."suspension_start_date" <= ? AND
               ("quota_suspension_periods"."suspension_end_date" >= ? OR
                "quota_suspension_periods"."suspension_end_date" IS NULL))
         LIMIT 1
        )
      SQL
    )
  end

  def apply_not_suspended_filter
    Sequel.lit(
      <<~SQL, QuotaDefinition.point_in_time, QuotaDefinition.point_in_time
        NOT EXISTS (
        SELECT *
          FROM "quota_suspension_periods"
         WHERE "quota_suspension_periods"."quota_definition_sid" = "quota_definitions"."quota_definition_sid" AND
               ("quota_suspension_periods"."suspension_start_date" <= ? AND
               ("quota_suspension_periods"."suspension_end_date" >= ? OR
                "quota_suspension_periods"."suspension_end_date" IS NULL))
         LIMIT 1
        )
      SQL
    )
  end

  # A quota definition is "Open" when it has no exhausted event, is not
  # currently suspended, is not currently blocked, and isn't flagged as
  # critical.
  def apply_open_filter
    not_exhausted = apply_not_exhausted_filter
    not_suspended = apply_not_suspended_filter
    not_blocked = apply_not_blocked_filter

    Sequel.lit(
      "#{not_exhausted.str} AND #{not_suspended.str} AND #{not_blocked.str} AND \"quota_definitions\".\"critical_state\" != 'Y'",
      *not_exhausted.args,
      *not_suspended.args,
      *not_blocked.args,
    )
  end
end

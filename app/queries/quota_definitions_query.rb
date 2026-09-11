# Builds the filtered dataset of Measures used to look up quota definitions.

class QuotaDefinitionsQuery
  STATUS_VALUES = %w[blocked exhausted not_blocked not_exhausted suspended not_suspended open].freeze

  class InvalidStatus < StandardError; end

  SqlFragment = Struct.new(:str, :args)

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
    area = GeographicalArea.where(geographical_area_id:).actual.first
    geographical_area_ids = area&.included_geographical_areas&.pluck(:geographical_area_id).to_a
    geographical_area_ids << geographical_area_id

    scope.where(measures__geographical_area_id: geographical_area_ids)
  end

  def apply_order_number_filter(scope)
    scope.where(measures__ordernumber: order_number)
  end

  def apply_quota_definition_filter(scope)
    critical_condition = critical.present? ? 'AND quota_definitions."critical_state" = \'Y\'' : ''
    args = [date, date]
    status_condition = ''
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

  def apply_exhausted_filter
    status_equals(QuotaDefinition::STATUS_EXHAUSTED)
  end

  def apply_not_exhausted_filter
    status_not_equals(QuotaDefinition::STATUS_EXHAUSTED)
  end

  def apply_blocked_filter
    status_equals(QuotaDefinition::STATUS_BLOCKED)
  end

  def apply_not_blocked_filter
    status_not_equals(QuotaDefinition::STATUS_BLOCKED)
  end

  def apply_suspended_filter
    status_equals(QuotaDefinition::STATUS_SUSPENDED)
  end

  def apply_not_suspended_filter
    status_not_equals(QuotaDefinition::STATUS_SUSPENDED)
  end

  def apply_open_filter
    status_equals(QuotaDefinition::STATUS_OPEN)
  end

  def status_sql_fragment
    @status_sql_fragment ||= QuotaStatusSql.new(
      definition_table: :quota_definitions,
      point_in_time: date,
    ).to_fragment
  end

  def status_equals(status_value)
    fragment = status_sql_fragment
    sql_fragment("(#{fragment.str}) = '#{status_value}'", *fragment.args)
  end

  def status_not_equals(status_value)
    fragment = status_sql_fragment
    sql_fragment("(#{fragment.str}) IS DISTINCT FROM '#{status_value}'", *fragment.args)
  end

  def sql_fragment(str, *args)
    SqlFragment.new(str, args)
  end
end

class QuotaSearchService
  STATUS_VALUES = %w[blocked exhausted not_blocked not_exhausted].freeze
  DEFAULT_EAGER_LOAD_GRAPH = {
    quota_definition: [
      :measures,
      :quota_suspension_periods,
      :quota_blocking_periods,
      :quota_balance_events,
      { quota_order_number: [quota_order_number_origins: :geographical_area] },
    ],
  }.freeze

  attr_reader :scope, :goods_nomenclature_item_id, :geographical_area_id, :order_number,
              :critical, :years, :status, :current_page, :per_page, :date

  delegate :pagination_record_count, to: :scope

  def initialize(attributes, current_page, per_page)
    @attributes = attributes
    status_value = attributes['status']&.gsub(/[+ ]/, '_')
    status_value = '' unless STATUS_VALUES.include?(status_value)
    @status = ActiveSupport::StringInquirer.new(status_value || '')
    @goods_nomenclature_item_id = attributes['goods_nomenclature_item_id']
    @geographical_area_id = attributes['geographical_area_id']
    @order_number = attributes['order_number']
    @critical = attributes['critical']
    @current_page = current_page
    @per_page = per_page
  end

  def call
    @scope = Measure
      .actual
      .join(:quota_definitions, [%i[measures__ordernumber quota_definitions__quota_order_number_id]])
      .eager(eager_load_graph)
      .distinct(:measures__ordernumber, :measures__validity_start_date)
      .select(Sequel.expr(:measures).*)
      .order(:measures__ordernumber)

    apply_goods_nomenclature_item_id_filter if goods_nomenclature_item_id.present?
    apply_geographical_area_id_filter if geographical_area_id.present?
    apply_order_number_filter if order_number.present?
    apply_critical_filter if critical.present?
    apply_status_filters if status.present?

    @scope = scope.paginate(current_page, per_page)

    scope.map(&:quota_definition).compact
  end

  private

  attr_reader :attributes

  def eager_load_graph
    eager_load = DEFAULT_EAGER_LOAD_GRAPH.dup

    eager_load[:quota_definition] << :quota_exhaustion_events if status.exhausted? || status.not_exhausted?

    eager_load
  end

  def includes
    @includes ||= attributes.fetch(:includes, [])
  end

  def apply_goods_nomenclature_item_id_filter
    @scope = scope.where(Sequel.like(:measures__goods_nomenclature_item_id, "#{goods_nomenclature_item_id}%"))
  end

  def apply_geographical_area_id_filter
    @scope = scope.where(measures__geographical_area_id: geographical_area_id)
  end

  def apply_order_number_filter
    @scope = scope.where(Sequel.like(:measures__ordernumber, "#{order_number}%"))
  end

  def apply_critical_filter
    @scope = scope.where(quota_definitions__critical_state: critical)
  end

  def apply_status_filters
    send("apply_#{status}_filter")
  end

  def apply_exhausted_filter
    sql = Sequel.lit(
      <<~SQL, QuotaDefinition.point_in_time
        EXISTS (
        SELECT *
          FROM "quota_exhaustion_events"
         WHERE "quota_exhaustion_events"."quota_definition_sid" = "quota_definitions"."quota_definition_sid" AND
               "quota_exhaustion_events"."occurrence_timestamp" <= ?
         LIMIT 1
        )
      SQL
    )

    @scope = scope.where(sql)
  end

  def apply_not_exhausted_filter
    sql = Sequel.lit(
      <<~SQL, QuotaDefinition.point_in_time
        NOT EXISTS (
        SELECT *
          FROM "quota_exhaustion_events"
         WHERE "quota_exhaustion_events"."quota_definition_sid" = "quota_definitions"."quota_definition_sid" AND
               "quota_exhaustion_events"."occurrence_timestamp" <= ?
         LIMIT 1
        )
      SQL
    )

    @scope = scope.where(sql)
  end

  def apply_blocked_filter
    sql = Sequel.lit(
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

    @scope = scope.where(sql)
  end

  def apply_not_blocked_filter
    sql = Sequel.lit(
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

    @scope = scope.where(sql)
  end
end

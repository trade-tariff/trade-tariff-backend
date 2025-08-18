class QuotaSearchService
  STATUS_VALUES = %w[blocked exhausted not_blocked not_exhausted].freeze
  DEFAULT_EAGER_LOAD_GRAPH = {
    quota_order_number: [
      { quota_order_number_origins: [{ geographical_area: :geographical_area_descriptions }] },
    ],
    quota_definition: [
      { measures: [{ geographical_area: :geographical_area_description }] },
      :quota_suspension_periods,
      :quota_blocking_periods,
      :quota_balance_events,
      {
        quota_order_number: [
          {
            quota_order_number_origins: [
              { geographical_area: :geographical_area_descriptions },
              {
                quota_order_number_origin_exclusions: [
                  { geographical_area: :geographical_area_descriptions },
                ],
              },
            ],
          },
        ],
      },
    ],
  }.freeze

  attr_reader :scope, :goods_nomenclature_item_id, :geographical_area_id, :order_number,
              :critical, :years, :status, :current_page, :per_page, :date

  def initialize(attributes, current_page, per_page, date)
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
    @date = date
  end

  def call
    @scope = Measure
      .actual
      .with_actual(QuotaDefinition)
      .join(:quota_definitions, [%i[measures__ordernumber quota_definitions__quota_order_number_id]])
      .eager(eager_load_graph)
      .distinct(:measures__ordernumber)
      .select(Sequel.expr(:measures).*)
      .order(:measures__ordernumber)

    apply_goods_nomenclature_item_id_filter if goods_nomenclature_item_id.present?
    apply_geographical_area_id_filter if geographical_area_id.present?
    apply_order_number_filter if order_number.present?
    apply_critical_filter if critical.present?
    apply_status_filters if status.present?

    @scope = @scope.paginate(current_page, per_page)

    @scope.map(&:quota_definition)
  end

  def pagination_record_count
    @scope = Measure.actual

    apply_quota_definition

    apply_goods_nomenclature_item_id_filter if goods_nomenclature_item_id.present?
    apply_geographical_area_id_filter if geographical_area_id.present?
    apply_order_number_filter if order_number.present?

    @scope.count(Sequel.lit('DISTINCT ordernumber'))
  end


  private

  attr_reader :attributes

  def eager_load_graph
    eager_load = DEFAULT_EAGER_LOAD_GRAPH.dup

    eager_load[:quota_definition] << :quota_exhaustion_events if status.exhausted? || status.not_exhausted?

    eager_load
  end

  def apply_goods_nomenclature_item_id_filter
    ancestors = FindAncestorsService.new(goods_nomenclature_item_id).call

    @scope = if ancestors.present?
               @scope.where(goods_nomenclature_item_id: ancestors)
             else
               @scope.where(Sequel.like(:measures__goods_nomenclature_item_id, "#{goods_nomenclature_item_id}%"))
             end
  end

  def apply_geographical_area_id_filter
    geographical_area_ids = GeographicalArea.where(geographical_area_id:).actual.take.included_geographical_areas.pluck(:geographical_area_id)
    geographical_area_ids << geographical_area_id

    @scope = scope.where(measures__geographical_area_id: geographical_area_ids)
  end

  def apply_order_number_filter
    @scope = scope.where(Sequel.like(:measures__ordernumber, "#{order_number}%"))
  end

  def apply_critical_filter
    @scope = scope.where(quota_definitions__critical_state: critical)
  end

  def apply_quota_definition
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

    @scope = scope.where(sql)
  end
  def apply_status_filters
    sql = send("apply_#{status}_filter")
    @scope = scope.where(sql)
  end

  def apply_exhausted_filter
    Sequel.lit(
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
  end

  def apply_not_exhausted_filter
    Sequel.lit(
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
end

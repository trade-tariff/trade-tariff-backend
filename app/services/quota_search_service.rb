class QuotaSearchService
  STATUS_VALUES = %w[blocked exhausted not_blocked not_exhausted].freeze

  attr_accessor :scope
  attr_reader :goods_nomenclature_item_id, :geographical_area_id, :order_number,
              :critical, :years, :status, :current_page, :per_page

  delegate :pagination_record_count, to: :scope

  def initialize(attributes, current_page, per_page)
    self.scope = Measure
      .eager(quota_definition: [:measures, :quota_exhaustion_events, :quota_blocking_periods, quota_order_number: [quota_order_number_origins: :geographical_area]])
      .join(:quota_definitions, [%i[measures__ordernumber quota_definitions__quota_order_number_id], %i[measures__validity_start_date quota_definitions__validity_start_date]])
      .distinct(:measures__ordernumber, :measures__validity_start_date)
      .select(Sequel.expr(:measures).*)
      .exclude(measures__ordernumber: nil)
      .order(:measures__ordernumber)
      .with_actual(Measure)

    @goods_nomenclature_item_id = attributes['goods_nomenclature_item_id']
    @geographical_area_id = attributes['geographical_area_id']
    @order_number = attributes['order_number']
    @critical = attributes['critical']
    @years = Array.wrap(attributes['years']).join(', ')
    status_value = attributes['status']&.gsub(/[+ ]/, '_')
    @status = status_value if STATUS_VALUES.include?(status_value)
    @current_page = current_page
    @per_page = per_page
  end

  def perform
    apply_goods_nomenclature_item_id_filter if goods_nomenclature_item_id.present?
    apply_geographical_area_id_filter if geographical_area_id.present?
    apply_order_number_filter if order_number.present?
    apply_critical_filter if critical.present?
    apply_years_filter if years.present?
    apply_status_filters if status.present?

    self.scope = scope.paginate(current_page, per_page)
    scope.map(&:quota_definition_or_nil)
  end

  private

  def apply_goods_nomenclature_item_id_filter
    self.scope = scope.where(Sequel.like(:measures__goods_nomenclature_item_id, "#{goods_nomenclature_item_id}%"))
  end

  def apply_geographical_area_id_filter
    self.scope = scope.where(measures__geographical_area_id: geographical_area_id)
  end

  def apply_order_number_filter
    self.scope = scope.where(Sequel.like(:measures__ordernumber, "#{order_number}%"))
  end

  def apply_critical_filter
    self.scope = scope.where(quota_definitions__critical_state: critical)
  end

  def apply_years_filter
    # TODO: This doesn't propagate to the validity start/end date of related resources
    #       Really we should use the time machine to work this out
    @scope = scope.where("EXTRACT(YEAR FROM measures.validity_start_date) IN (#{years})")
  end

  def apply_status_filters
    send("apply_#{status}_filter")
  end

  def apply_exhausted_filter
    @scope = scope
      .where(
        <<~SQL,
          EXISTS (
          SELECT *
            FROM "quota_exhaustion_events"
           WHERE "quota_exhaustion_events"."quota_definition_sid" = "quota_definitions"."quota_definition_sid" AND
                 "quota_exhaustion_events"."occurrence_timestamp" <= '#{QuotaDefinition.point_in_time}'
           LIMIT 1
          )
        SQL
      )
  end

  def apply_not_blocked_filter
    @scope = scope
      .where(
        <<~SQL,
          NOT EXISTS (
          SELECT *
            FROM "quota_blocking_periods"
           WHERE "quota_blocking_periods"."quota_definition_sid" = "quota_definitions"."quota_definition_sid" AND
                 ("quota_blocking_periods"."blocking_start_date" <= '#{QuotaDefinition.point_in_time}' AND
                 ("quota_blocking_periods"."blocking_end_date" >= '#{QuotaDefinition.point_in_time}' OR
                  "quota_blocking_periods"."blocking_end_date" IS NULL))
           LIMIT 1
          )
        SQL
      )
  end
end

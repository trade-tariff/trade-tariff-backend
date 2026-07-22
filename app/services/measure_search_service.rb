class MeasureSearchService
  ALLOWED_SERIES = ('A'..'J').to_a + %w[Q].freeze
  TRADE_DIRECTION_CODES = {
    'import' => [0, 2],
    'export' => [1, 2],
  }.freeze
  MAX_PER_PAGE = 100

  EAGER_GRAPH = {
    measure_type: :measure_type_description,
    geographical_area: :geographical_area_descriptions,
    measure_excluded_geographical_areas: [],
  }.freeze

  attr_reader :filters, :current_page, :per_page

  def initialize(filters:, page:, per_page:)
    @filters = filters
    @current_page = page.to_i.clamp(1, Float::INFINITY)
    @per_page = per_page.to_i.clamp(1, MAX_PER_PAGE)
  end

  def call
    base_scope.eager(EAGER_GRAPH)
              .order(:measure_type_id, :geographical_area_id, :goods_nomenclature_item_id)
              .paginate(current_page, per_page, pagination_record_count)
              .all
  end

  def pagination_record_count
    @pagination_record_count ||= base_scope.count
  end

private

  def base_scope
    scope = Measure.actual
    scope = apply_series_filter(scope)
    scope = apply_measure_type_ids_filter(scope)
    scope = apply_geographical_area_filter(scope)
    scope = apply_no_geographical_exclusions_filter(scope)
    scope = apply_no_exemption_conditions_filter(scope)
    scope = apply_trade_direction_filter(scope)
    apply_commodity_prefix_filter(scope)
  end

  def apply_series_filter(scope)
    series = Array(filters[:measure_type_series]).map(&:upcase).select { _1.in?(ALLOWED_SERIES) }
    return scope if series.empty?

    type_ids = MeasureType.where(measure_type_series_id: series).select_map(:measure_type_id)
    scope.where(measure_type_id: type_ids)
  end

  def apply_measure_type_ids_filter(scope)
    ids = Array(filters[:measure_type_ids]).map(&:to_s).reject(&:blank?)
    return scope if ids.empty?

    scope.where(measure_type_id: ids)
  end

  def apply_geographical_area_filter(scope)
    area_id = filters[:geographical_area_id].presence
    return scope if area_id.nil?

    if area_id == 'erga_omnes'
      scope.where(geographical_area_id: GeographicalArea::ERGA_OMNES_ID)
    else
      scope.where(geographical_area_id: area_id)
    end
  end

  def apply_no_geographical_exclusions_filter(scope)
    return scope unless filters[:has_no_geographical_exclusions].to_s == 'true'

    scope.exclude(measure_sid: MeasureExcludedGeographicalArea.select(:measure_sid))
  end

  def apply_no_exemption_conditions_filter(scope)
    return scope unless filters[:has_no_exemption_conditions].to_s == 'true'

    scope.exclude(measure_sid: MeasureCondition.where(certificate_type_code: 'Y').select(:measure_sid))
  end

  def apply_trade_direction_filter(scope)
    direction = filters[:trade_direction].to_s.downcase
    codes = TRADE_DIRECTION_CODES[direction]
    return scope if codes.nil?

    type_ids = MeasureType.where(trade_movement_code: codes).select_map(:measure_type_id)
    scope.where(measure_type_id: type_ids)
  end

  def apply_commodity_prefix_filter(scope)
    prefix = filters[:commodity_code_prefix].to_s.gsub(/\D/, '')
    return scope unless prefix.length.between?(2, 10)

    scope.where(Sequel.like(:goods_nomenclature_item_id, "#{prefix}%"))
  end
end

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

  def initialize(filters:, page:, per_page:, as_of: nil)
    @filters = filters
    @current_page = page.to_i.clamp(1, Float::INFINITY)
    @per_page = per_page.to_i.clamp(1, MAX_PER_PAGE)
    @as_of = as_of
  end

  def call
    TimeMachine.at(as_of_or_now) do
      base_scope.eager(EAGER_GRAPH)
                .order(:measure_type_id, :geographical_area_id, :goods_nomenclature_item_id)
                .paginate(current_page, per_page, pagination_record_count)
                .all
    end
  end

  def summarize
    TimeMachine.at(as_of_or_now) do
      scope = base_scope

      type_series_map = MeasureType.select_map(%i[measure_type_id measure_type_series_id]).to_h

      type_id_counts = scope.naked
                            .group_and_count(:measure_type_id)
                            .map { [_1[:measure_type_id], _1[:count]] }
                            .to_h

      by_geo = scope.naked
                    .group_and_count(:geographical_area_id)
                    .map { [_1[:geographical_area_id], _1[:count]] }
                    .to_h

      by_series = type_id_counts.each_with_object(Hash.new(0)) do |(type_id, count), acc|
        series = type_series_map[type_id]
        acc[series] += count if series
      end

      {
        total_count: type_id_counts.values.sum,
        by_series:,
        by_geographical_area: by_geo,
      }
    end
  end

  def pagination_record_count
    @pagination_record_count ||= TimeMachine.at(as_of_or_now) { base_scope.count }
  end

private

  def as_of_or_now
    @as_of || Time.current
  end

  def base_scope
    scope = Measure.actual
    scope = apply_series_filter(scope)
    scope = apply_measure_type_ids_filter(scope)
    scope = apply_geographical_area_filter(scope)
    scope = apply_no_geographical_exclusions_filter(scope)
    scope = apply_no_exemption_conditions_filter(scope)
    scope = apply_trade_direction_filter(scope)
    scope = apply_commodity_prefix_filter(scope)
    scope = apply_condition_code_filter(scope)
    scope = apply_regulation_id_filter(scope)
    apply_has_ad_valorem_filter(scope)
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

  def apply_condition_code_filter(scope)
    codes = Array(filters[:measure_condition_codes]).map(&:upcase).reject(&:blank?)
    return scope if codes.empty?

    scope.where(measure_sid: MeasureCondition.where(condition_code: codes).select(:measure_sid))
  end

  def apply_regulation_id_filter(scope)
    regulation_id = filters[:regulation_id].presence
    return scope if regulation_id.nil?

    scope.where(measure_generating_regulation_id: regulation_id)
  end

  def apply_has_ad_valorem_filter(scope)
    return scope unless filters[:has_ad_valorem].to_s == 'true'

    # Ad valorem components have no monetary_unit_code (percentage-based duties)
    scope.where(measure_sid: MeasureComponent.where(monetary_unit_code: nil).select(:measure_sid))
  end
end

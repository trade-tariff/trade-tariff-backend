class CachedCommodityService
  include DeclarableSerialization

  CACHE_VERSION = 3

  DEFAULT_INCLUDES = (DECLARABLE_INCLUDES + %w[
    heading
    ancestors
    import_measures.resolved_measure_components
    import_measures.resolved_measure_components.measurement_unit
    import_measures.measure_components.measurement_unit
    export_measures.resolved_measure_components
    export_measures.resolved_measure_components.measurement_unit
    export_measures.measure_components.measurement_unit
  ]).freeze

  MEASURES_EAGER_LOAD_GRAPH = [
    { footnotes: :footnote_descriptions },
    { measure_type: :measure_type_description },
    {
      measure_components: [
        { duty_expression: :duty_expression_description },
        { measurement_unit: %i[measurement_unit_description measurement_unit_abbreviations] },
        { measure: { measure_type: :measure_type_description } },
        :monetary_unit,
        { measurement_unit_qualifier: :measurement_unit_qualifier_description },
      ],
    },
    {
      measure_conditions: [
        { measure_action: :measure_action_description },
        { certificate: :certificate_descriptions },
        { certificate_type: :certificate_type_description },
        { measurement_unit: %i[measurement_unit_description measurement_unit_abbreviations] },
        :appendix_5a,
        :monetary_unit,
        :measurement_unit_qualifier,
        { measure_condition_code: :measure_condition_code_description },
        {
          measure_condition_components: [
            { duty_expression: :duty_expression_description },
            { measurement_unit: %i[measurement_unit_description measurement_unit_abbreviations] },
            :measure_condition,
            :monetary_unit,
            :measurement_unit_qualifier,
          ],
        },
      ],
    },
    { quota_order_number: { quota_definition: %i[quota_balance_events quota_suspension_periods quota_blocking_periods] } },
    { excluded_geographical_areas: :geographical_area_descriptions },
    { geographical_area: [:geographical_area_descriptions,
                          { contained_geographical_areas: :geographical_area_descriptions }] },
    { additional_code: :additional_code_descriptions },
    :base_regulation,
    :modification_regulation,
    :full_temporary_stop_regulations,
    :measure_partial_temporary_stops,
  ].freeze

  TTL = 24.hours

  def initialize(commodity, actual_date, filters = {})
    @commodity = commodity
    @actual_date = actual_date
    @filters = filters
  end

  def call
    Rails.cache.fetch(cache_key, expires_in: TTL) do
      Api::V2::Commodities::CommoditySerializer.new(presented_commodity, options).serializable_hash
    end
  end

  private

  attr_reader :commodity, :actual_date, :filters

  def presented_commodity
    Api::V2::Commodities::CommodityPresenter.new(commodity, filtered_measures)
  end

  def filtered_measures
    MeasureCollection.new(measures, filters).filter
  end

  def options
    {}.tap do |opts|
      opts[:is_collection] = false
      opts[:include] = DEFAULT_INCLUDES
    end
  end

  def measures
    commodity.measures_dataset.eager(*MEASURES_EAGER_LOAD_GRAPH).all
  end

  def geographical_area_id
    filters[:geographical_area_id]
  end

  def meursing_additional_code_id
    Thread.current[:meursing_additional_code_id]
  end

  def cache_key
    "_commodity-v#{CACHE_VERSION}-#{commodity.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}-#{geographical_area_id}-#{meursing_additional_code_id}"
  end
end

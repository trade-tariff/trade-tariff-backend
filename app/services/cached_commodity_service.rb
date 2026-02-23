class CachedCommodityService
  include DeclarableSerialization

  CACHE_VERSION = 4

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
    {
      excluded_geographical_areas: [
        :geographical_area_descriptions,
        :contained_geographical_areas,
        { referenced: :contained_geographical_areas },
      ],
    },
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
    @commodity_sid = commodity.goods_nomenclature_sid
    @actual_date = actual_date
    @filters = filters
  end

  def call
    cached_data = Rails.cache.fetch(cache_key, expires_in: TTL) do
      presenter = presented_commodity
      hash = Api::V2::Commodities::CommoditySerializer.new(presenter, options).serializable_hash
      measure_meta = MeasureMetadataBuilder.new(presenter).build

      { v: CACHE_VERSION, hash: hash, measure_meta: measure_meta }
    end

    ResponseFilter.new(cached_data, geographical_area_id).call
  end

  private

  attr_reader :actual_date, :filters

  def presented_commodity
    Api::V2::Commodities::CommodityPresenter.new(commodity, excise_filtered_measures)
  end

  def excise_filtered_measures
    MeasureCollection.new(measures, {}).apply_excise_filter
  end

  def options
    {}.tap do |opts|
      opts[:is_collection] = false
      opts[:include] = DEFAULT_INCLUDES
    end
  end

  def commodity
    @commodity ||= Commodity
      .actual
      .where(goods_nomenclature_sid: @commodity_sid)
      .eager(ancestors: { measures: MEASURES_EAGER_LOAD_GRAPH,
                          goods_nomenclature_descriptions: {} },
             measures: MEASURES_EAGER_LOAD_GRAPH)
      .take
  end

  def measures
    commodity.applicable_measures
  end

  def geographical_area_id
    filters[:geographical_area_id]
  end

  def meursing_additional_code_id
    TradeTariffRequest.meursing_additional_code_id
  end

  def cache_key
    "_commodity-v#{CACHE_VERSION}-#{@commodity_sid}-#{actual_date}-#{TradeTariffBackend.currency}-#{meursing_additional_code_id}"
  end
end

class CachedCommodityService
  DEFAULT_INCLUDES = [
    'section',
    'chapter',
    'chapter.guides',
    'heading',
    'ancestors',
    'footnotes',
    'import_measures',
    'import_measures.duty_expression',
    'import_measures.measure_type',
    'import_measures.legal_acts',
    'import_measures.suspending_regulation',
    'import_measures.measure_conditions',
    'import_measures.measure_conditions.measure_condition_components',
    'import_measures.measure_components',
    'import_measures.national_measurement_units',
    'import_measures.geographical_area',
    'import_measures.geographical_area.contained_geographical_areas',
    'import_measures.excluded_geographical_areas',
    'import_measures.footnotes',
    'import_measures.additional_code',
    'import_measures.order_number',
    'import_measures.order_number.definition',
    'export_measures',
    'export_measures.duty_expression',
    'export_measures.measure_type',
    'export_measures.legal_acts',
    'export_measures.suspending_regulation',
    'export_measures.measure_conditions',
    'export_measures.measure_conditions.measure_condition_components',
    'export_measures.measure_components',
    'export_measures.national_measurement_units',
    'export_measures.geographical_area',
    'export_measures.geographical_area.contained_geographical_areas',
    'export_measures.excluded_geographical_areas',
    'export_measures.footnotes',
    'export_measures.additional_code',
    'export_measures.order_number',
    'export_measures.order_number.definition',
  ].freeze

  MEASURES_EAGER_LOAD_GRAPH = [
    { footnotes: :footnote_descriptions },
    { measure_type: :measure_type_description },
    {
      measure_components: [
        { duty_expression: :duty_expression_description },
        { measurement_unit: %i[measurement_unit_description measurement_unit_abbreviations] },
        { measure: { measure_type: :measure_type_description } },
        :monetary_unit,
        :measurement_unit_qualifier,
      ],
    },
    {
      measure_conditions: [
        { measure_action: :measure_action_description },
        { certificate: :certificate_descriptions },
        { certificate_type: :certificate_type_description },
        { measurement_unit: %i[measurement_unit_description measurement_unit_abbreviations] },
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

  def initialize(commodity, actual_date, filter_params)
    @commodity = commodity
    @actual_date = actual_date
    @filter_params = filter_params || {}
  end

  def call
    Rails.cache.fetch(cache_key, expires_in: TTL) do
      Api::V2::Commodities::CommoditySerializer.new(presented_commodity, options).serializable_hash
    end
  end

  private

  attr_reader :commodity, :actual_date, :filter_params

  def presented_commodity
    Api::V2::Commodities::CommodityPresenter.new(commodity, presented_measures)
  end

  def presented_measures
    # TODO: This should be Api::V2::Measures::MeasurePresenter. It works currently because the real presenter used by the CommodityPresenter uses the correct V2 measures presenter.
    #       Also, why are we validating in a presenter?
    MeasurePresenter.new(measures, commodity).validate!
  end

  def options
    {}.tap do |opts|
      opts[:is_collection] = false
      opts[:include] = DEFAULT_INCLUDES
      opts[:params] = {}

      opts[:params][:meursing_additional_code_id] = meursing_additional_code_id if meursing_additional_code_id.present?
    end
  end

  def measures
    measures = commodity.measures_dataset.eager(*MEASURES_EAGER_LOAD_GRAPH).all
    return measures unless geographical_area_id.present? && filtering_country.present?

    apply_filter(measures, filtering_country)
  end

  def geographical_area_id
    filter_params[:geographical_area_id]
  end

  def meursing_additional_code_id
    filter_params[:meursing_additional_code_id]
  end

  def cache_key
    "_commodity-#{commodity.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}-#{geographical_area_id}-#{meursing_additional_code_id}"
  end

  def filtering_country
    @filtering_country ||= GeographicalArea.find(geographical_area_id: filter_params[:geographical_area_id])
  end

  def apply_filter(measures, filtering_country)
    measures.select do |measure|
      measure.relevant_for_country?(filtering_country.geographical_area_id)
    end
  end
end

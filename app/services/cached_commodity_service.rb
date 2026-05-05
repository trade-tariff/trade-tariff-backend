class CachedCommodityService
  include DeclarableSerialization

  CACHE_VERSION = 6

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

  # All measure associations except quota — loaded for every commodity.
  BASE_MEASURES_EAGER_LOAD_GRAPH = [
    { footnotes: :footnote_descriptions },
    { measure_type: %i[measure_type_description measure_type_series_description] },
    {
      measure_components: [
        { duty_expression: :duty_expression_description },
        { measurement_unit: %i[measurement_unit_description measurement_unit_abbreviations] },
        :monetary_unit,
        { measurement_unit_qualifier: :measurement_unit_qualifier_description },
      ],
    },
    {
      measure_conditions: [
        { measure_action: :measure_action_description },
        { certificate: %i[certificate_descriptions exempting_certificate_override] },
        { certificate_type: :certificate_type_description },
        { measurement_unit: %i[measurement_unit_description measurement_unit_abbreviations] },
        :appendix_5a,
        :monetary_unit,
        { measurement_unit_qualifier: :measurement_unit_qualifier_description },
        { measure_condition_code: :measure_condition_code_description },
        {
          measure_condition_components: [
            { duty_expression: :duty_expression_description },
            { measurement_unit: %i[measurement_unit_description measurement_unit_abbreviations] },
            :monetary_unit,
            :measurement_unit_qualifier,
          ],
        },
      ],
    },
    {
      geographical_area: [
        :geographical_area_descriptions,
        { contained_geographical_areas: %i[geographical_area_descriptions contained_geographical_areas] },
        { referenced: { contained_geographical_areas: :contained_geographical_areas } },
      ],
    },
    {
      excluded_geographical_areas: [
        :geographical_area_descriptions,
        :contained_geographical_areas,
        { referenced: :contained_geographical_areas },
      ],
    },
    { additional_code: :additional_code_descriptions },
    :base_regulation,
    { modification_regulation: :base_regulation },
    :justification_base_regulation,
    :justification_modification_regulation,
    :full_temporary_stop_regulations,
    :measure_partial_temporary_stops,
  ].freeze

  # Quota sub-graph loaded only when at least one applicable measure has an
  # ordernumber — most commodities never have quota measures, so skipping
  # this sub-graph when it is not needed avoids 6 unnecessary queries.
  QUOTA_EAGER_LOAD_GRAPH = {
    quota_definition: %i[
      quota_balance_events
      quota_suspension_periods
      quota_blocking_periods
      incoming_quota_closed_and_transferred_event
    ],
  }.freeze

  # Full graph retained as a convenience reference (e.g. tests that use
  # the old single-call eager load path to build a reference response).
  MEASURES_EAGER_LOAD_GRAPH = (BASE_MEASURES_EAGER_LOAD_GRAPH + [
    { quota_order_number: QUOTA_EAGER_LOAD_GRAPH },
  ]).freeze

  def initialize(commodity, actual_date, filters = {})
    @commodity_sid = commodity.goods_nomenclature_sid
    @actual_date = actual_date
    @filters = filters
  end

  def ttl
    actual_date.to_date == Time.zone.today ? 24.hours : 2.hours
  end

  def call
    cached_data = Rails.cache.fetch(cache_key, expires_in: ttl) do
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
    @commodity ||= begin
      result = Commodity
        .actual
        .with_leaf_column
        .where(goods_nomenclatures__goods_nomenclature_sid: @commodity_sid)
        .eager(
          goods_nomenclature_descriptions: {},
          heading: :footnotes,
          chapter: [:chapter_note, { sections: :section_note }],
          ancestors: { measures: BASE_MEASURES_EAGER_LOAD_GRAPH,
                       goods_nomenclature_descriptions: {} },
          measures: BASE_MEASURES_EAGER_LOAD_GRAPH,
          full_chemicals: {},
        )
        .take

      load_quota_associations(result)
      result
    end
  end

  # Eager-load quota_order_number and its definition sub-tree only for
  # measures that actually have a quota (ordernumber is present).  Most
  # commodities have none, so this avoids 6 superfluous queries per request.
  # When quota measures do exist, a single batched query loads all relevant
  # QuotaOrderNumbers and their sub-associations in one pass.
  def load_quota_associations(commodity)
    all_measures = commodity.measures + commodity.ancestors.flat_map(&:measures)
    quota_measures = all_measures.select { |m| m.ordernumber.present? }
    return if quota_measures.empty?

    ordernumbers = quota_measures.map(&:ordernumber).uniq

    quota_order_numbers = QuotaOrderNumber
      .where(quota_order_number_id: ordernumbers)
      .eager(QUOTA_EAGER_LOAD_GRAPH)
      .all

    quota_by_ordernumber = quota_order_numbers.index_by(&:quota_order_number_id)

    quota_measures.each do |measure|
      measure.associations[:quota_order_number] = quota_by_ordernumber[measure.ordernumber]
    end
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

  # Only fragment the cache by meursing code when the commodity actually has
  # meursing measures (types 672, 673, 674 — agricultural duty add-ons).
  # Most commodities (e.g. vehicles, electronics) never have these, so
  # including the code in the key would create N identical cache entries —
  # one per distinct meursing code seen in requests — for no benefit.
  def effective_meursing_code
    return nil if meursing_additional_code_id.blank?

    commodity_has_meursing_measures? ? meursing_additional_code_id : nil
  end

  # Cached per commodity+date so we pay at most one DB query per commodity
  # per day. The result is stable within a trading day; the 24-hour TTL
  # matches the commodity response TTL for today's date.
  def commodity_has_meursing_measures?
    Rails.cache.fetch(
      "commodity-has-meursing-#{@commodity_sid}-#{actual_date}",
      expires_in: ttl,
    ) do
      Measure.actual
             .where(goods_nomenclature_sid: @commodity_sid)
             .where(measure_type_id: MeasureType::MEURSING_MEASURES)
             .any?
    end
  end

  def cache_key
    "_commodity-v#{CACHE_VERSION}-#{@commodity_sid}-#{actual_date}-#{effective_meursing_code}"
  end
end

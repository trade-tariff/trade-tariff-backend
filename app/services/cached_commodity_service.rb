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

  MEASURES_EAGER_LOAD_GRAPH = [
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
      quota_order_number: {
        quota_definition: %i[
          quota_balance_events
          quota_suspension_periods
          quota_blocking_periods
          incoming_quota_closed_and_transferred_event
        ],
      },
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
      # Phase 1: load the commodity and its ancestors for their own attributes.
      # Measures are deliberately excluded here and loaded in a separate
      # batched pass below so that MEASURES_EAGER_LOAD_GRAPH is applied once
      # across all applicable goods_nomenclature_sids instead of twice
      # (once for own measures, once for ancestor measures).
      result = Commodity
        .actual
        .with_leaf_column
        .where(goods_nomenclatures__goods_nomenclature_sid: @commodity_sid)
        .eager(
          goods_nomenclature_descriptions: {},
          heading: :footnotes,
          chapter: [:chapter_note, { sections: :section_note }],
          ancestors: :goods_nomenclature_descriptions,
          full_chemicals: {},
        )
        .take

      load_applicable_measures(result)
      result
    end
  end

  def measures
    commodity.applicable_measures
  end

  # Fetches all measures for the commodity and every ancestor in one batched
  # Sequel query, then distributes them back into each object's :measures
  # association slot. This halves the number of queries compared with loading
  # own measures and ancestor measures with separate eager-load passes.
  def load_applicable_measures(commodity)
    all_sids = [commodity.goods_nomenclature_sid] +
      commodity.ancestors.map(&:goods_nomenclature_sid)

    all_measures = Measure
      .actual
      .dedupe_similar
      .with_regulation_dates_query
      .without_excluded_types
      .where(goods_nomenclature_sid: all_sids)
      .eager(MEASURES_EAGER_LOAD_GRAPH)
      .all

    measures_by_sid = all_measures.group_by(&:goods_nomenclature_sid)

    commodity.associations[:measures] = measures_by_sid.fetch(commodity.goods_nomenclature_sid, [])
    commodity.ancestors.each do |ancestor|
      ancestor.associations[:measures] = measures_by_sid.fetch(ancestor.goods_nomenclature_sid, [])
    end
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

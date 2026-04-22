class CachedCommodityService
  include DeclarableSerialization

  CACHE_VERSION = 5

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

  # Single unified eager-load graph for all measures associations.
  #
  # IMPORTANT: Do not split this into two arrays and concatenate them.
  # Sequel's eager_options_for_associations builds a flat hash from the array
  # via opts.merge!(association). If the same association key appears twice —
  # even as a bare symbol vs a nested hash — the later entry silently overwrites
  # the earlier one, dropping all nested sub-associations from the first entry.
  # This was the root cause of ~491 N+1 queries on commodities#show:
  #
  #   :geographical_area  appeared in both arrays → geographical_area_descriptions dropped
  #   :measure_type       appeared in both arrays → measure_type_series_description dropped
  #   :measure_components appeared in both arrays → duty_expression sub-load dropped
  #   :additional_code    appeared in both arrays → additional_code_descriptions dropped
  #
  # Every association that is needed for both payload serialisation and measure
  # filtering/metadata is listed once here, with the union of all nested
  # associations required by either use.
  MEASURES_EAGER_LOAD_GRAPH = [
    { footnotes: :footnote_descriptions },
    # Load both description associations so the serializer can access
    # measure_type_series_description without a per-measure lazy query.
    # measure_type is also used by MeasureCollection filter logic.
    { measure_type: %i[measure_type_description measure_type_series_description] },
    # measure_components is used by MeasureCollection filter logic AND serialised
    # via MeasureComponentSerializer. The nested associations cover both.
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
        # exempting_certificate_override is accessed in
        # MeasureCondition#is_exempting_certificate_overridden? (called by the
        # condition permutations calculator). Without it, every condition that
        # has a certificate fires a separate query.
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
    # geographical_area_descriptions is needed by GeographicalAreaSerializer.
    # contained_geographical_areas (with descriptions) is needed by the
    # serializer for group members. referenced + its contained_geographical_areas
    # is needed by GeographicalRelevance#contained_area_ids to resolve
    # area-group references without per-measure lazy queries.
    {
      geographical_area: [
        :geographical_area_descriptions,
        { contained_geographical_areas: :geographical_area_descriptions },
        { referenced: :contained_geographical_areas },
      ],
    },
    # excluded_geographical_areas are used by MeasureCollection filter logic.
    {
      excluded_geographical_areas: [
        :geographical_area_descriptions,
        :contained_geographical_areas,
        { referenced: :contained_geographical_areas },
      ],
    },
    # additional_code is used by MeasureCollection filter logic AND serialised.
    { additional_code: :additional_code_descriptions },
    :base_regulation,
    # Measure#legal_acts appends generating_regulation.base_regulation for
    # modification-regulation-backed measures (to include the parent base
    # regulation in the legal acts list). Loading it nested here means a single
    # batch query instead of one per such measure.
    { modification_regulation: :base_regulation },
    # Batch-load both directions of the justification regulation so
    # Measure#justification_regulation uses the cache instead of a raw .find.
    :justification_base_regulation,
    :justification_modification_regulation,
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
      .with_leaf_column
      .where(goods_nomenclatures__goods_nomenclature_sid: @commodity_sid)
      .eager(
        # Descriptions are delegated through goods_nomenclature_descriptions.first;
        # without this the commodity's own description triggers a lazy load.
        goods_nomenclature_descriptions: {},
        # CommodityPresenter combines commodity.footnotes + heading.footnotes.
        # Without the nested :footnotes the heading is loaded separately.
        heading: :footnotes,
        # ChapterSerializer renders chapter_note; section comes via
        # chapter.sections.first and SectionSerializer renders section_note.
        chapter: [:chapter_note, { sections: :section_note }],
        ancestors: { measures: MEASURES_EAGER_LOAD_GRAPH,
                     goods_nomenclature_descriptions: {} },
        measures: MEASURES_EAGER_LOAD_GRAPH,
      )
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

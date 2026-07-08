module JsonapiSwaggerChangeIncludes
  CHANGE_INCLUDES = %w[
    record
    record.geographical_area
    record.measure_type
  ].freeze
end

module JsonapiSwaggerMeasureIncludes
  MEASURE_INCLUDES = %w[
    goods_nomenclature
    duty_expression
    measure_type
    legal_acts
    measure_generating_legal_act
    justification_legal_act
    measure_conditions
    measure_conditions.measure_condition_components
    measure_components
    geographical_area
    geographical_area.contained_geographical_areas
    excluded_geographical_areas
    footnotes
    additional_code
    order_number
    order_number.definition
  ].freeze

  DECLARABLE_MEASURE_INCLUDES = %w[
    import_measures
    import_measures.duty_expression
    import_measures.measure_type
    import_measures.legal_acts
    import_measures.suspending_regulation
    import_measures.measure_conditions
    import_measures.measure_conditions.measure_condition_code
    import_measures.measure_condition_permutation_groups
    import_measures.measure_condition_permutation_groups.permutations
    import_measures.measure_conditions.measure_condition_components
    import_measures.measure_components
    import_measures.measure_components.measurement_unit
    import_measures.measure_components.measurement_unit_qualifier
    import_measures.geographical_area
    import_measures.geographical_area.contained_geographical_areas
    import_measures.excluded_geographical_areas
    import_measures.footnotes
    import_measures.additional_code
    import_measures.order_number
    import_measures.order_number.definition
    import_measures.order_number.definition.incoming_quota_closed_and_transferred_event
    import_measures.preference_code
    export_measures
    export_measures.duty_expression
    export_measures.measure_type
    export_measures.legal_acts
    export_measures.suspending_regulation
    export_measures.measure_conditions
    export_measures.measure_conditions.measure_condition_code
    export_measures.measure_condition_permutation_groups
    export_measures.measure_condition_permutation_groups.permutations
    export_measures.measure_conditions.measure_condition_components
    export_measures.measure_components
    export_measures.measure_components.measurement_unit
    export_measures.measure_components.measurement_unit_qualifier
    export_measures.geographical_area
    export_measures.geographical_area.contained_geographical_areas
    export_measures.excluded_geographical_areas
    export_measures.footnotes
    export_measures.additional_code
    export_measures.order_number
    export_measures.order_number.definition
  ].freeze
end

module JsonapiSwaggerGoodsNomenclatureIncludes
  COMMODITY_INCLUDES = ([
    'section',
    'chapter',
    'chapter.guides',
    'footnotes',
    'import_trade_summary',
    'heading',
    'ancestors',
    'import_measures.resolved_measure_components',
    'import_measures.resolved_measure_components.measurement_unit',
    'export_measures.resolved_measure_components',
    'export_measures.resolved_measure_components.measurement_unit',
  ] + JsonapiSwaggerMeasureIncludes::DECLARABLE_MEASURE_INCLUDES).uniq.freeze

  HEADING_INCLUDES = ([
    'section',
    'chapter',
    'chapter.guides',
    'footnotes',
    'commodities',
    'commodities.overview_measures',
    'commodities.overview_measures.duty_expression',
    'commodities.overview_measures.measure_type',
    'commodities.overview_measures.additional_code',
    'import_trade_summary',
  ] + JsonapiSwaggerMeasureIncludes::DECLARABLE_MEASURE_INCLUDES).uniq.freeze

  SUBHEADING_INCLUDES = %w[
    section
    heading
    chapter
    chapter.guides
    footnotes
    commodities
    commodities.overview_measures
    commodities.overview_measures.duty_expression
    commodities.overview_measures.measure_type
    commodities.overview_measures.additional_code
    ancestors
  ].freeze
end

module JsonapiSwaggerQuotaIncludes
  QUOTA_DEFAULT_INCLUDES = %w[
    quota_order_number
    quota_order_number.geographical_areas
    measures
    measures.goods_nomenclature
    measures.geographical_area
    incoming_quota_closed_and_transferred_event
    quota_order_number_origins
    quota_order_number_origins.geographical_area
    quota_order_number_origins.quota_order_number_origin_exclusions
    quota_order_number_origins.quota_order_number_origin_exclusions.geographical_area
  ].freeze

  QUOTA_INCLUDES = %w[
    quota_balance_events
  ].freeze

  QUOTA_ORDER_NUMBER_INCLUDES = %w[
    quota_definition
    quota_definition.measures
  ].freeze
end

module JsonapiSwaggerRulesOfOriginIncludes
  RULES_OF_ORIGIN_MINIMAL_INCLUDES = %w[
    links
    origin_reference_document
    proofs
  ].freeze

  RULES_OF_ORIGIN_FULL_INCLUDES = %w[
    links
    proofs
    rules
    articles
    rule_sets
    rule_sets.rules
    origin_reference_document
  ].freeze
end

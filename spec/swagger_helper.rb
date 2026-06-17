require 'rails_helper'

TARIFF_API_HOST = 'https://www.trade-tariff.service.gov.uk'.freeze

module JsonapiSwaggerParameters
  CHANGE_INCLUDES = %w[
    record
    record.geographical_area
    record.measure_type
  ].freeze

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
  ] + DECLARABLE_MEASURE_INCLUDES).uniq.freeze

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
  ] + DECLARABLE_MEASURE_INCLUDES).uniq.freeze

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

  def jsonapi_query_parameters(includes:, default_includes: [])
    # TODO: Enable if desired to make this widely accessible.
  end
end

RSpec.configure do |config|
  config.extend JsonapiSwaggerParameters

  config.openapi_root = Rails.root.join('swagger').to_s

  config.openapi_specs = {
    'v2/swagger.json' => {
      openapi: '3.0.1',
      info: {
        title: 'UK Trade Tariff API',
        version: 'v2',
        description: <<~DESC,
          GOV.UK Online Trade Tariff API. Provides access to UK Global Tariff and
          Northern Ireland (XI) tariff data including commodity codes, duty rates,
          certificates, quotas, and trade restrictions.

          API version is negotiated via the `Accept` header. All V2 requests must
          include `Accept: application/vnd.hmrc.2.0+json`.
        DESC
        contact: {
          name: 'Trade Tariff Support',
          url: 'https://www.trade-tariff.service.gov.uk',
        },
        license: {
          name: 'MIT',
          url: 'https://opensource.org/licenses/MIT',
        },
      },
      servers: [
        {
          url: "#{TARIFF_API_HOST}/uk",
          description: 'Production (UK Global Tariff)',
        },
        {
          url: "#{TARIFF_API_HOST}/xi",
          description: 'Production (Northern Ireland)',
        },
      ],
      components: {
        parameters: {
          accept_header: {
            name: 'Accept',
            in: :header,
            required: true,
            schema: {
              type: :string,
              enum: ['application/vnd.hmrc.2.0+json'],
              default: 'application/vnd.hmrc.2.0+json',
            },
            description: 'API version negotiation header. Must be `application/vnd.hmrc.2.0+json`.',
          },
        },
        schemas: {
          error_response: {
            type: :object,
            description: 'Standard error response',
            properties: {
              errors: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    code: { type: :string, description: 'Machine-readable error code' },
                    detail: { type: :string, description: 'Human-readable error message' },
                  },
                  required: %w[code detail],
                },
              },
            },
            required: %w[errors],
          },
        },
      },
    },
  }

  config.openapi_format = :json
end

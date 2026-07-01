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

module SwaggerSecurityParameters
  # Rswag reads header parameters by method name, including OpenAPI header casing.
  # rubocop:disable Naming/MethodName
  define_method(:Authorization) { 'Bearer test-token' }
  # rubocop:enable Naming/MethodName
end

RSpec.configure do |config|
  config.extend JsonapiSwaggerParameters
  config.include SwaggerSecurityParameters, type: :request

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
      security: [
        {
          oauth2_client_credentials: ['tariff/read'],
        },
      ],
      components: {
        securitySchemes: {
          oauth2_client_credentials: {
            type: :oauth2,
            description: 'OAuth 2.0 client credentials authentication for Trade Tariff API clients.',
            flows: {
              clientCredentials: {
                tokenUrl: 'https://auth.id.trade-tariff.service.gov.uk/oauth2/token',
                scopes: {
                  'tariff/read' => 'Read public Trade Tariff API data.',
                  'tariff/write' => 'Write Trade Tariff API data where an endpoint explicitly supports it.',
                },
              },
            },
          },
        },
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
          AsOfDate: {
            name: :as_of,
            in: :query,
            required: false,
            schema: {
              type: :string,
              format: :date,
              pattern: '^\\d{4}-\\d{2}-\\d{2}$',
            },
            description: 'Return tariff data that was valid on this date, formatted as `YYYY-MM-DD`. Defaults to the current date when omitted.',
          },
          Include: {
            name: :include,
            in: :query,
            required: false,
            schema: {
              type: :string,
            },
            description: 'Comma-separated JSON:API relationship paths to include in the response. Supported values vary by endpoint.',
          },
          Filter: {
            name: :filter,
            in: :query,
            required: false,
            style: :deepObject,
            explode: true,
            schema: {
              type: :object,
              additionalProperties: true,
            },
            description: 'Endpoint-specific filter object using `filter[name]=value` query parameters.',
          },
          PageNumber: {
            name: :page,
            in: :query,
            required: false,
            schema: {
              type: :integer,
              minimum: 1,
              default: 1,
            },
            description: 'Page number for paginated responses. Defaults to `1`.',
          },
          PageSize: {
            name: :per_page,
            in: :query,
            required: false,
            schema: {
              type: :integer,
              minimum: 1,
              default: 20,
            },
            description: 'Number of records to return per page for paginated responses. Defaults to `20` when supported by the endpoint.',
          },
        },
        schemas: {
          SimpleErrorResponse: {
            type: :object,
            description: 'Error response returned by shared API rescue handlers when a request cannot be processed.',
            properties: {
              error: {
                type: :string,
                description: 'Short human-readable error message.',
              },
              url: {
                type: :string,
                format: :uri,
                description: 'Request URL that produced the error, when supplied by the endpoint.',
              },
            },
            required: %w[error],
          },
          JsonApiErrorResponse: {
            type: :object,
            description: 'JSON:API error response returned by V2 endpoints.',
            properties: {
              errors: {
                type: :array,
                description: 'One or more errors that explain why the request failed.',
                items: {
                  type: :object,
                  properties: {
                    status: {
                      type: :string,
                      description: 'HTTP status code associated with the error, when supplied by the endpoint.',
                    },
                    title: {
                      type: :string,
                      description: 'Short error title or affected attribute, when supplied by the endpoint.',
                    },
                    detail: {
                      type: :string,
                      description: 'Human-readable explanation of the error.',
                    },
                    source: {
                      type: :object,
                      description: 'Location of the invalid request value, when supplied by the endpoint.',
                      properties: {
                        pointer: {
                          type: :string,
                          description: 'JSON Pointer to the related request member.',
                        },
                      },
                    },
                  },
                },
              },
            },
            required: %w[errors],
          },
          error_response: {
            type: :object,
            description: 'Deprecated alias for JSON:API error responses. Use `JsonApiErrorResponse` for new endpoint documentation.',
            properties: {
              errors: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    status: { type: :string, description: 'HTTP status code associated with the error, when supplied by the endpoint.' },
                    title: { type: :string, description: 'Short error title or affected attribute, when supplied by the endpoint.' },
                    detail: { type: :string, description: 'Human-readable explanation of the error.' },
                    source: {
                      type: :object,
                      description: 'Location of the invalid request value, when supplied by the endpoint.',
                      properties: {
                        pointer: { type: :string, description: 'JSON Pointer to the related request member.' },
                      },
                    },
                  },
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

require 'rails_helper'

TARIFF_API_HOST = 'https://www.trade-tariff.service.gov.uk'.freeze

module JsonapiSwaggerParameters
  CHANGE_INCLUDES = JsonapiSwaggerChangeIncludes::CHANGE_INCLUDES
  MEASURE_INCLUDES = JsonapiSwaggerMeasureIncludes::MEASURE_INCLUDES
  DECLARABLE_MEASURE_INCLUDES = JsonapiSwaggerMeasureIncludes::DECLARABLE_MEASURE_INCLUDES
  COMMODITY_INCLUDES = JsonapiSwaggerGoodsNomenclatureIncludes::COMMODITY_INCLUDES
  HEADING_INCLUDES = JsonapiSwaggerGoodsNomenclatureIncludes::HEADING_INCLUDES
  SUBHEADING_INCLUDES = JsonapiSwaggerGoodsNomenclatureIncludes::SUBHEADING_INCLUDES
  QUOTA_DEFAULT_INCLUDES = JsonapiSwaggerQuotaIncludes::QUOTA_DEFAULT_INCLUDES
  QUOTA_INCLUDES = JsonapiSwaggerQuotaIncludes::QUOTA_INCLUDES
  QUOTA_ORDER_NUMBER_INCLUDES = JsonapiSwaggerQuotaIncludes::QUOTA_ORDER_NUMBER_INCLUDES
  RULES_OF_ORIGIN_MINIMAL_INCLUDES = JsonapiSwaggerRulesOfOriginIncludes::RULES_OF_ORIGIN_MINIMAL_INCLUDES
  RULES_OF_ORIGIN_FULL_INCLUDES = JsonapiSwaggerRulesOfOriginIncludes::RULES_OF_ORIGIN_FULL_INCLUDES

  def jsonapi_query_parameters(includes:, default_includes: [])
    # TODO: Enable if desired to make this widely accessible.
  end
end

module SwaggerSecurityParameters
  AUTHORIZATION_HEADER = :Authorization

  # Rswag dispatches OAuth-derived header names as messages and does not expose
  # the `getter:` override supported by ordinary OpenAPI parameters.
  def method_missing(method_name, ...)
    return 'Bearer test-token' if method_name == AUTHORIZATION_HEADER

    super
  end

  def respond_to_missing?(method_name, include_private = false)
    method_name == AUTHORIZATION_HEADER || super
  end
end

module SwaggerErrorResponses
  def standard_bad_request_response
    response '400', 'bad request' do
      schema '$ref' => '#/components/schemas/StandardErrorResponse'

      it 'documents the error response schema' do |example|
        expect(example.metadata.dig(:response, :schema, '$ref')).to eq('#/components/schemas/StandardErrorResponse')
      end
    end
  end

  def standard_not_found_response
    response '404', 'not found' do
      schema '$ref' => '#/components/schemas/StandardErrorResponse'

      it 'documents the error response schema' do |example|
        expect(example.metadata.dig(:response, :schema, '$ref')).to eq('#/components/schemas/StandardErrorResponse')
      end
    end
  end

  def standard_unprocessable_content_response
    response '422', 'unprocessable content' do
      schema '$ref' => '#/components/schemas/StandardErrorResponse'

      it 'documents the error response schema' do |example|
        expect(example.metadata.dig(:response, :schema, '$ref')).to eq('#/components/schemas/StandardErrorResponse')
      end
    end
  end

  def standard_error_responses
    standard_bad_request_response
    standard_not_found_response
    standard_unprocessable_content_response
  end
end

RSpec.configure do |config|
  config.extend JsonapiSwaggerParameters
  config.extend SwaggerErrorResponses
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
                  'tariff/categorisation' => 'Read Categorisation API data (Northern Ireland only). Issued separately from tariff/read and tariff/write.',
                },
              },
            },
          },
        },
        parameters: {
          accept_header: {
            name: 'Accept',
            getter: :accept,
            in: :header,
            required: true,
            schema: {
              type: :string,
              enum: ['application/vnd.hmrc.2.0+json'],
              default: 'application/vnd.hmrc.2.0+json',
            },
            description: 'API version negotiation header. Use `application/vnd.hmrc.2.0+json` for V2 JSON responses.',
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
          StandardErrorResponse: {
            oneOf: [
              { '$ref' => '#/components/schemas/JsonApiErrorResponse' },
              { '$ref' => '#/components/schemas/SimpleErrorResponse' },
            ],
            description: 'Error response returned by documented V2 endpoint failures.',
          },
          SimpleErrorResponse: {
            type: :object,
            description: 'Error response returned by shared API rescue handlers.',
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
                      oneOf: [
                        { type: :string },
                        { type: :integer },
                      ],
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
                    status: {
                      oneOf: [
                        { type: :string },
                        { type: :integer },
                      ],
                      description: 'HTTP status code associated with the error, when supplied by the endpoint.',
                    },
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

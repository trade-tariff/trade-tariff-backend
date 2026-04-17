require 'rails_helper'

RSpec.configure do |config|
  config.swagger_root = Rails.root.join('swagger').to_s

  config.swagger_docs = {
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
          url: 'https://www.trade-tariff.service.gov.uk/uk',
          description: 'Production (UK Global Tariff)',
        },
        {
          url: 'https://www.trade-tariff.service.gov.uk/xi',
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

  config.swagger_format = :json
end

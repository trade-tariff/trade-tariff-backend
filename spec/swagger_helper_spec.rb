require 'swagger_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'swagger helper configuration' do
  # rubocop:enable RSpec/DescribeClass
  subject(:swagger_doc) { RSpec.configuration.openapi_specs.fetch('v2/swagger.json') }

  let(:components) { swagger_doc.fetch(:components) }

  it 'sets public endpoints to require read-only OAuth scope by default' do
    expect(swagger_doc.fetch(:security)).to eq(
      [
        {
          oauth2_client_credentials: ['tariff/read'],
        },
      ],
    )
  end

  it 'defines reusable OAuth client credentials security metadata' do
    security_scheme = components.fetch(:securitySchemes).fetch(:oauth2_client_credentials)

    expect(security_scheme).to eq(
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
    )
  end

  it 'defines reusable JSON:API error responses' do
    responses = components.fetch(:responses)

    expect(responses.fetch(:BadRequest)).to include(
      description: 'The request is malformed or contains unsupported parameters.',
      content: {
        'application/json' => {
          schema: { '$ref' => '#/components/schemas/JsonApiErrorResponse' },
        },
      },
    )
    expect(responses.fetch(:NotFound)).to include(
      description: 'The requested resource could not be found.',
      content: {
        'application/json' => {
          schema: { '$ref' => '#/components/schemas/JsonApiErrorResponse' },
        },
      },
    )
    expect(responses.fetch(:UnprocessableContent)).to include(
      description: 'The request was understood but failed validation.',
      content: {
        'application/json' => {
          schema: { '$ref' => '#/components/schemas/JsonApiErrorResponse' },
        },
      },
    )
  end

  it 'defines a reusable JSON:API error schema that matches V2 serializers' do
    schema = components.fetch(:schemas).fetch(:JsonApiErrorResponse)
    error = schema.fetch(:properties).fetch(:errors).fetch(:items)

    expect(schema).to include(type: :object, required: %w[errors])
    expect(error.fetch(:properties)).to include(
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
    )
  end

  it 'defines reusable common request parameters' do
    parameters = components.fetch(:parameters)

    expect(parameters.keys).to include(
      :accept_header,
      :AsOfDate,
      :Include,
      :Filter,
      :PageNumber,
      :PageSize,
    )
  end
end

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

  it 'defines a reusable simple error schema that matches shared rescue handlers' do
    schema = components.fetch(:schemas).fetch(:SimpleErrorResponse)

    expect(schema).to include(type: :object, required: %w[error])
    expect(schema.fetch(:properties)).to include(
      error: { type: :string, description: 'Short human-readable error message.' },
      url: { type: :string, format: :uri, description: 'Request URL that produced the error, when supplied by the endpoint.' },
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

  it 'documents commodity lookup with endpoint-specific usage guidance and key field descriptions' do
    generated_doc = JSON.parse(Rails.root.join('swagger/v2/swagger.json').read)
    path_item = generated_doc.dig('paths', '/api/commodities/{id}')
    operation = path_item.fetch('get')
    parameters = path_item.fetch('parameters', []) + operation.fetch('parameters', [])
    data_schema = operation.dig('responses', '200', 'content', 'application/json', 'schema', 'properties', 'data')
    attributes = data_schema.dig('properties', 'attributes', 'properties')
    relationships = data_schema.dig('properties', 'relationships', 'properties')

    expect(operation.fetch('description')).to include('Use this endpoint when you already have a 10-digit commodity code')
    expect(operation.fetch('description')).to include('Use the `/uk` server for UK Global Tariff data and the `/xi` server for Northern Ireland data')
    expect(parameters.pluck('name')).to include(
      'filter[geographical_area_id]',
      'filter[meursing_additional_code_id]',
    )
    expect(attributes.fetch('goods_nomenclature_item_id').fetch('description')).to include('10-digit commodity code')
    expect(attributes.fetch('declarable').fetch('description')).to include('true when this commodity can be declared')
    expect(relationships.fetch('import_measures').fetch('description')).to include('Import duties, controls, restrictions, quotas, and other import measures')
    expect(relationships.fetch('export_measures').fetch('description')).to include('Export controls, restrictions, duties, and other export measures')
    expect(operation.dig('responses', '404', 'content', 'application/json', 'schema', '$ref')).to eq('#/components/schemas/SimpleErrorResponse')
  end
end

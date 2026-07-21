require 'swagger_helper'

RSpec.describe 'Certificates', swagger_doc: 'v2/swagger.json', type: :request do
  let(:accept) { 'application/vnd.hmrc.2.0+json' }

  certificate_list_item_schema = {
    type: :object,
    required: %w[id type attributes],
    properties: {
      id: { type: :string, description: 'Combined certificate type and certificate code.' },
      type: { type: :string, enum: %w[certificate], description: 'JSON:API resource type.' },
      attributes: {
        type: :object,
        properties: {
          certificate_type_code: { type: :string, nullable: true, description: 'Single-character document type code.' },
          certificate_code: { type: :string, nullable: true, description: 'Document code within the certificate type.' },
          description: { type: :string, nullable: true, description: 'Certificate description.' },
          formatted_description: { type: :string, nullable: true, description: 'Certificate description formatted for display.' },
          guidance_cds: { type: :string, nullable: true, description: 'CDS guidance text for the certificate, when available.' },
          certificate_type_description: { type: :string, nullable: true, description: 'Description of the certificate type, when returned by this endpoint.' },
          validity_start_date: { type: :string, nullable: true, format: 'date-time', description: 'Date and time from which this certificate description is valid.' },
        },
      },
    },
  }.freeze

  certificate_search_item_schema = {
    type: :object,
    required: %w[id type attributes],
    properties: {
      id: { type: :string, description: 'Combined certificate type and certificate code.' },
      type: { type: :string, enum: %w[certificates], description: 'JSON:API resource type returned by certificate search.' },
      attributes: {
        type: :object,
        properties: {
          certificate_type_code: { type: :string, nullable: true, description: 'Single-character document type code.' },
          certificate_code: { type: :string, nullable: true, description: 'Document code within the certificate type.' },
          description: { type: :string, nullable: true, description: 'Certificate description.' },
          formatted_description: { type: :string, nullable: true, description: 'Certificate description formatted for display.' },
          guidance_cds: { type: :string, nullable: true, description: 'CDS guidance text for the certificate, when available.' },
        },
      },
      relationships: {
        type: :object,
        properties: {
          goods_nomenclatures: {
            type: :object,
            description: 'Goods nomenclature records linked to matching measures.',
          },
        },
      },
    },
  }.freeze

  path '/api/certificates' do
    parameter name: :Accept, getter: :accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'Accept header for V2 JSON responses. Use `application/vnd.hmrc.2.0+json`.'

    get 'List all certificates' do
      tags 'Certificates'
      produces 'application/json'
      jsonapi_query_parameters(includes: [])
      description 'List current certificate document codes, ordered by certificate type code and certificate code.'
      operationId 'listCertificates'

      response '200', 'certificates listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: certificate_list_item_schema,
                 },
               }

        before { create(:certificate, :with_description, :with_certificate_type, :with_guidance) }

        run_test!
      end

      standard_error_responses
    end
  end

  path '/api/certificates/search' do
    parameter name: :Accept, getter: :accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'Accept header for V2 JSON responses. Use `application/vnd.hmrc.2.0+json`.'
    parameter name: :description, in: :query, required: false,
              schema: { type: :string },
              description: 'Partial certificate description to search for. Required when `type` and `code` are both omitted.'
    parameter name: :type, in: :query, required: false,
              schema: { type: :string },
              description: 'Certificate type code. Must be supplied with `code` when used.'
    parameter name: :code, in: :query, required: false,
              schema: { type: :string },
              description: 'Certificate code. Must be supplied with `type` when used.'

    get 'Search certificates' do
      tags 'Certificates'
      produces 'application/json'
      jsonapi_query_parameters(includes: %w[goods_nomenclatures])
      description 'Search certificate document codes by description, or by type and code together. Results include matching certificates and can include related goods nomenclatures.'
      operationId 'searchCertificates'

      response '200', 'certificates found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: certificate_search_item_schema,
                 },
               }

        let(:description) { 'test' }

        run_test!
      end

      response '422', 'invalid certificate search parameters' do
        schema '$ref' => '#/components/schemas/StandardErrorResponse'

        let(:type) { 'Y' }

        run_test!
      end

      standard_bad_request_response
      standard_not_found_response
    end
  end
end

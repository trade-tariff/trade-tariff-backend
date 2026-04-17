require 'swagger_helper'

RSpec.describe 'Certificates', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  certificate_item_schema = {
    type: :object,
    properties: {
      id: { type: :string },
      type: { type: :string, enum: %w[certificate] },
      attributes: {
        type: :object,
        properties: {
          certificate_type_code: { type: :string, nullable: true },
          certificate_code: { type: :string, nullable: true },
          description: { type: :string, nullable: true },
          formatted_description: { type: :string, nullable: true },
          guidance_cds: { type: :string, nullable: true },
          certificate_type_description: { type: :string, nullable: true },
          validity_start_date: { type: :string, nullable: true, format: 'date-time' },
        },
      },
    },
  }.freeze

  path '/uk/api/certificates' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'

    get 'List all certificates' do
      tags 'Certificates'
      produces 'application/json'
      description 'Returns all current certificates ordered by type and code.'
      operationId 'listCertificates'

      response '200', 'certificates listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: certificate_item_schema,
                 },
               }

        before { create(:certificate, :with_description, :with_certificate_type, :with_guidance) }

        run_test!
      end
    end
  end

  path '/uk/api/certificates/search' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :description, in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by certificate description (partial match)'
    parameter name: :type, in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by certificate type code'
    parameter name: :code, in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by certificate code'

    get 'Search certificates' do
      tags 'Certificates'
      produces 'application/json'
      description 'Returns certificates matching the search parameters, including related goods nomenclatures.'
      operationId 'searchCertificates'

      response '200', 'certificates found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: certificate_item_schema,
                 },
               }

        let(:description) { 'test' }

        run_test!
      end
    end
  end
end

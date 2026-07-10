require 'swagger_helper'

RSpec.describe 'Certificates V3', swagger_doc: 'v3/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.3.0+json' }

  path '/api/v3/certificates' do
    get 'List all certificates' do
      tags 'Certificates'
      produces 'application/json'
      operationId 'listCertificatesV3'

      response '200', 'certificates listed' do
        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       certificate_type_code: { type: :string },
                       certificate_code: { type: :string },
                       description: { type: :string, nullable: true },
                       validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                       validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                     },
                   },
                 },
                 meta: { '$ref' => '#/components/schemas/meta' },
               }

        before { create(:certificate, :with_description) }

        run_test!
      end
    end
  end

  path '/api/v3/certificate_types' do
    get 'List all certificate types' do
      tags 'Certificates'
      produces 'application/json'
      operationId 'listCertificateTypesV3'

      response '200', 'certificate types listed' do
        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       certificate_type_code: { type: :string },
                       description: { type: :string, nullable: true },
                       validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                       validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                     },
                   },
                 },
                 meta: { '$ref' => '#/components/schemas/meta' },
               }

        before { create(:certificate_type, :with_description) }

        run_test!
      end
    end
  end
end

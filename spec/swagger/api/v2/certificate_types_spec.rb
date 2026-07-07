require 'swagger_helper'

RSpec.describe 'Certificate Types', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/certificate_types' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'Accept header for V2 JSON responses. Use `application/vnd.hmrc.2.0+json`.'

    get 'List all certificate types' do
      tags 'Certificates'
      produces 'application/json'
      jsonapi_query_parameters(includes: [])
      description 'List certificate type codes used to group certificate document codes.'
      operationId 'listCertificateTypes'

      response '200', 'certificate types listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string, description: 'Certificate type code.' },
                       type: { type: :string, enum: %w[certificate_type], description: 'JSON:API resource type.' },
                       attributes: {
                         type: :object,
                         properties: {
                           certificate_type_code: { type: :string, nullable: true, description: 'Single-character certificate type code.' },
                           description: { type: :string, nullable: true, description: 'Certificate type description.' },
                         },
                       },
                     },
                   },
                 },
               }

        before { create(:certificate_type, :with_description) }

        run_test!
      end
    end
  end
end

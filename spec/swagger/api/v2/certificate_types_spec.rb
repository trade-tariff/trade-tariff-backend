require 'swagger_helper'

RSpec.describe 'Certificate Types', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/uk/api/certificate_types' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'

    get 'List all certificate types' do
      tags 'Certificates'
      produces 'application/json'
      description 'Returns all certificate types with their descriptions.'
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
                       id: { type: :string },
                       type: { type: :string, enum: %w[certificate_type] },
                       attributes: {
                         type: :object,
                         properties: {
                           certificate_type_code: { type: :string, nullable: true },
                           description: { type: :string, nullable: true },
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

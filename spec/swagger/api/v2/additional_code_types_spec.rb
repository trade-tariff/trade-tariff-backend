require 'swagger_helper'

RSpec.describe 'Additional Code Types', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/additional_code_types' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'

    get 'List all additional code types' do
      tags 'Additional Codes'
      produces 'application/json'
      description 'Returns all additional code types.'
      operationId 'listAdditionalCodeTypes'

      response '200', 'additional code types listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[additional_code_type] },
                       attributes: {
                         type: :object,
                         properties: {
                           additional_code_type_id: { type: :string, nullable: true },
                           description: { type: :string, nullable: true },
                         },
                       },
                     },
                   },
                 },
               }

        let(:act) { create(:additional_code_type) }
        before { create(:additional_code_type_description, additional_code_type_id: act.additional_code_type_id) }

        run_test!
      end
    end
  end
end

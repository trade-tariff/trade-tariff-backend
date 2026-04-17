require 'swagger_helper'

RSpec.describe 'Additional Codes', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/uk/api/additional_codes/search' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :description, in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by additional code description (partial match)'
    parameter name: :type, in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by additional code type ID'
    parameter name: :code, in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by additional code value'

    get 'Search additional codes' do
      tags 'Additional Codes'
      produces 'application/json'
      description 'Returns additional codes matching the search parameters, including related goods nomenclatures.'
      operationId 'searchAdditionalCodes'

      response '200', 'additional codes found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[additional_code] },
                       attributes: {
                         type: :object,
                         properties: {
                           additional_code_type_id: { type: :string, nullable: true },
                           additional_code: { type: :string, nullable: true },
                           code: { type: :string, nullable: true },
                           description: { type: :string, nullable: true },
                           formatted_description: { type: :string, nullable: true },
                         },
                       },
                     },
                   },
                 },
               }

        let(:description) { 'test' }

        run_test!
      end
    end
  end
end

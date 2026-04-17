require 'swagger_helper'

RSpec.describe 'Search References', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/search_references' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: 'query[letter]', in: :query, required: false,
              schema: { type: :string, maxLength: 1 },
              description: 'Filter by first letter of the search reference title'

    get 'List search references' do
      tags 'Search References'
      produces 'application/json'
      description 'Returns search references optionally filtered by first letter.'
      operationId 'listSearchReferences'

      response '200', 'search references listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[search_reference] },
                       attributes: {
                         type: :object,
                         properties: {
                           id: { type: :integer, nullable: true },
                           title: { type: :string, nullable: true },
                           referenced_class: { type: :string, nullable: true },
                         },
                       },
                     },
                   },
                 },
               }

        before { create(:search_reference) }

        run_test!
      end
    end
  end
end

require 'swagger_helper'

RSpec.describe 'Search References', swagger_doc: 'v2/swagger.json', type: :request do
  let(:accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/search_references' do
    parameter name: :Accept, getter: :accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: 'query[letter]', in: :query, required: false,
              schema: { type: :string, maxLength: 1 },
              description: 'Filter by first letter of the search reference title'
    parameter name: 'filter[usage]', getter: :filter_usage, in: :query, required: false,
              schema: { type: :string, enum: %w[search fpo all], default: 'search' },
              description: 'Filter by usage. `search` references are shown in public search. `fpo` references are used only to train the FPO classifier. `all` returns both.'

    get 'List search references' do
      tags 'Search References'
      produces 'application/json'
      jsonapi_query_parameters(includes: [])
      description 'Returns search references optionally filtered by first letter and usage. By default only `search` references are returned.'
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
                           usage: { type: :string, enum: %w[search fpo] },
                         },
                       },
                     },
                   },
                 },
               }

        before { create(:search_reference) }

        run_test!
      end

      response '400', 'unknown usage filter' do
        let(:filter_usage) { 'other' }

        run_test!
      end
    end
  end
end

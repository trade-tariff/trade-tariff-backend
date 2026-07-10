require 'swagger_helper'

RSpec.describe 'Search V3', swagger_doc: 'v3/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.3.0+json' }

  path '/api/v3/search' do
    get 'Search the tariff' do
      tags 'Search'
      produces 'application/json'
      operationId 'searchV3'
      description 'Full-text search across commodity codes, chapter and heading descriptions. Returns ranked results. Powered by OpenSearch.'

      parameter name: :q, in: :query, schema: { type: :string }, required: false,
                description: 'Search query string'

      response '200', 'search results' do
        schema type: :object

        let(:q) { 'live animals' }

        run_test!
      end
    end
  end
end

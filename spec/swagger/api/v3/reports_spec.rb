require 'swagger_helper'

RSpec.describe 'Reports V3', swagger_doc: 'v3/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.3.0+json' }

  path '/api/v3/reports' do
    get 'List available reports' do
      tags 'Reports'
      operationId 'listReportsV3'
      description 'Extensible reports namespace. Returns the list of available reports. Currently empty — reports will be added incrementally.'

      response '200', 'reports listed' do
        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: { type: :array, items: {}, description: 'Available reports (empty at launch)' },
                 meta: { '$ref' => '#/components/schemas/meta' },
               }

        run_test!
      end
    end
  end
end

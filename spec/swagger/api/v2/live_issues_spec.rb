require 'swagger_helper'

RSpec.describe 'Live Issues', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/uk/api/live_issues' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: 'filter[status]', in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by issue status (e.g. "Active")'

    get 'List live issues' do
      tags 'Live Issues'
      produces 'application/json'
      description 'Returns current live service issues, optionally filtered by status.'
      operationId 'listLiveIssues'

      response '200', 'live issues listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[live_issue] },
                       attributes: {
                         type: :object,
                         properties: {
                           title: { type: :string, nullable: true },
                           description: { type: :string, nullable: true },
                           suggested_action: { type: :string, nullable: true },
                           status: { type: :string, nullable: true },
                           date_discovered: { type: :string, nullable: true, format: 'date' },
                           commodities: {
                             type: :array,
                             nullable: true,
                             items: { type: :string },
                           },
                         },
                       },
                     },
                   },
                 },
               }

        before { create(:live_issue) }

        run_test!
      end
    end
  end
end

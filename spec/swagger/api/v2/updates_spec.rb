require 'swagger_helper'

RSpec.describe 'Updates', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/uk/api/updates/latest' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'

    get 'Retrieve the latest tariff updates' do
      tags 'Updates'
      produces 'application/json'
      description 'Returns the most recently applied tariff update records.'
      operationId 'getLatestUpdates'

      response '200', 'latest updates retrieved' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     required: %w[id type attributes],
                     properties: {
                       id: { type: :string, description: 'The update filename used as the record id' },
                       type: { type: :string, enum: %w[tariff_update] },
                       attributes: {
                         type: :object,
                         properties: {
                           update_type: { type: :string, nullable: true },
                           state: { type: :string, nullable: true },
                           created_at: { type: :string, nullable: true, format: 'date-time' },
                           updated_at: { type: :string, nullable: true, format: 'date-time' },
                           filename: { type: :string, nullable: true },
                           applied_at: { type: :string, nullable: true, format: 'date-time' },
                         },
                       },
                     },
                   },
                 },
               }

        before { create(:cds_update, :applied) }

        run_test!
      end
    end
  end
end

require 'swagger_helper'

RSpec.describe 'Measure Actions', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/measure_actions' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'

    get 'List all measure actions' do
      tags 'Measure Actions'
      produces 'application/json'
      description 'Returns all current measure actions with their descriptions.'
      operationId 'listMeasureActions'

      response '200', 'measure actions listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[measure_action] },
                       attributes: {
                         type: :object,
                         properties: {
                           action_code: { type: :string, nullable: true },
                           description: { type: :string, nullable: true },
                           validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                           validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                         },
                       },
                     },
                   },
                 },
               }

        before { create(:measure_action, :with_description) }

        run_test!
      end
    end
  end
end

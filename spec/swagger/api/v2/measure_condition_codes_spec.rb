require 'swagger_helper'

RSpec.describe 'Measure Condition Codes', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/uk/api/measure_condition_codes' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'

    get 'List all measure condition codes' do
      tags 'Measure Condition Codes'
      produces 'application/json'
      description 'Returns all current measure condition codes with their descriptions.'
      operationId 'listMeasureConditionCodes'

      response '200', 'measure condition codes listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[measure_condition_code] },
                       attributes: {
                         type: :object,
                         properties: {
                           condition_code: { type: :string, nullable: true },
                           description: { type: :string, nullable: true },
                           validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                           validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                         },
                       },
                     },
                   },
                 },
               }

        before { create(:measure_condition_code, :with_description) }

        run_test!
      end
    end
  end
end

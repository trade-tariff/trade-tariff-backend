require 'swagger_helper'

RSpec.describe 'Measure Condition Codes', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/measure_condition_codes' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'Accept header for V2 JSON responses. Use `application/vnd.hmrc.2.0+json`.'

    get 'List all measure condition codes' do
      tags 'Measure Condition Codes'
      produces 'application/json'
      jsonapi_query_parameters(includes: [])
      description 'List measure condition codes used in measure conditions, with current descriptions and validity dates.'
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
                       id: { type: :string, description: 'Measure condition code.' },
                       type: { type: :string, enum: %w[measure_condition_code], description: 'JSON:API resource type.' },
                       attributes: {
                         type: :object,
                         properties: {
                           condition_code: { type: :string, nullable: true, description: 'Code used on measure conditions.' },
                           description: { type: :string, nullable: true, description: 'Measure condition code description.' },
                           validity_start_date: { type: :string, nullable: true, format: 'date-time', description: 'Date and time from which this condition code is valid.' },
                           validity_end_date: { type: :string, nullable: true, format: 'date-time', description: 'Date and time after which this condition code is no longer valid, or null when current.' },
                         },
                       },
                     },
                   },
                 },
               }

        before { create(:measure_condition_code, :with_description) }

        run_test!
      end

      standard_error_responses
    end
  end
end

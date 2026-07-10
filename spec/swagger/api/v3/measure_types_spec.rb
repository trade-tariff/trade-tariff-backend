require 'swagger_helper'

RSpec.describe 'Measure Types V3', swagger_doc: 'v3/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.3.0+json' }

  path '/api/v3/measure_types' do
    get 'List all measure types' do
      tags 'Measure Types'
      produces 'application/json'
      operationId 'listMeasureTypesV3'

      response '200', 'measure types listed' do
        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     required: %w[id description],
                     properties: {
                       id: { type: :string },
                       description: { type: :string, nullable: true },
                       measure_type_series_id: { type: :string, nullable: true },
                       measure_type_series_description: { type: :string, nullable: true },
                       measure_component_applicable_code: { type: :integer, nullable: true },
                       order_number_capture_code: { type: :integer, nullable: true },
                       trade_movement_code: { type: :integer, nullable: true },
                       validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                       validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                     },
                   },
                 },
                 meta: { '$ref' => '#/components/schemas/meta' },
               }

        before { create(:measure_type) }

        run_test!
      end
    end
  end

  path '/api/v3/measure_types/{id}' do
    parameter name: :id, in: :path, schema: { type: :string, example: '103' }, required: true,
              description: 'Measure type ID'

    get 'Retrieve a measure type' do
      tags 'Measure Types'
      produces 'application/json'
      operationId 'getMeasureTypeV3'

      response '200', 'measure type found' do
        schema type: :object,
               required: %w[id description],
               properties: {
                 id: { type: :string },
                 description: { type: :string, nullable: true },
                 measure_type_series_id: { type: :string, nullable: true },
                 measure_type_series_description: { type: :string, nullable: true },
                 measure_component_applicable_code: { type: :integer, nullable: true },
                 order_number_capture_code: { type: :integer, nullable: true },
                 trade_movement_code: { type: :integer, nullable: true },
                 validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                 validity_end_date: { type: :string, nullable: true, format: 'date-time' },
               }

        let(:id) { create(:measure_type, measure_type_id: '103').measure_type_id }

        run_test!
      end

      response '404', 'measure type not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { 'ZZZ' }
        run_test!
      end
    end
  end
end

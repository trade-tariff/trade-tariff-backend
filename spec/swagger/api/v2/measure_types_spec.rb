require 'swagger_helper'

RSpec.describe 'Measure Types', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  measure_type_item_schema = {
    type: :object,
    properties: {
      id: { type: :string },
      type: { type: :string, enum: %w[measure_type] },
      attributes: {
        type: :object,
        properties: {
          id: { type: :string, nullable: true },
          description: { type: :string, nullable: true },
          measure_type_series_id: { type: :string, nullable: true },
          measure_component_applicable_code: { type: :integer, nullable: true },
          order_number_capture_code: { type: :integer, nullable: true },
          trade_movement_code: { type: :integer, nullable: true },
          validity_start_date: { type: :string, nullable: true, format: 'date-time' },
          validity_end_date: { type: :string, nullable: true, format: 'date-time' },
          measure_type_series_description: { type: :string, nullable: true },
        },
      },
    },
  }.freeze

  path '/api/measure_types' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'

    get 'List all measure types' do
      tags 'Measure Types'
      produces 'application/json'
      description 'Returns all current measure types with their series descriptions.'
      operationId 'listMeasureTypes'

      response '200', 'measure types listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: measure_type_item_schema,
                 },
               }

        before { create(:measure_type) }

        run_test!
      end
    end
  end

  path '/api/measure_types/{id}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :string },
              description: 'Measure type ID (e.g. "142")'

    get 'Retrieve a measure type' do
      tags 'Measure Types'
      produces 'application/json'
      description 'Returns a single measure type by its ID.'
      operationId 'getMeasureType'

      response '200', 'measure type found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: measure_type_item_schema,
               }

        let(:measure_type) { create(:measure_type) }
        let(:id) { measure_type.measure_type_id }

        run_test!
      end

      response '404', 'measure type not found' do
        let(:id) { 'NOTFOUND' }

        run_test!
      end
    end
  end
end

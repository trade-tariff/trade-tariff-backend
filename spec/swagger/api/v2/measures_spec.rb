require 'swagger_helper'

RSpec.describe 'Measures', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/measures/{id}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :integer },
              description: 'Measure SID (may be negative for national measures)'

    get 'Retrieve a measure' do
      tags 'Measures'
      produces 'application/json'
      description 'Returns a single measure including its duty expression, conditions, components, and geographical area.'
      operationId 'getMeasure'

      response '200', 'measure found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :object,
                   required: %w[id type attributes],
                   properties: {
                     id: { type: :string },
                     type: { type: :string, enum: %w[measure] },
                     attributes: {
                       type: :object,
                       properties: {
                         origin: { type: :string, nullable: true },
                         import: { type: :boolean },
                         export: { type: :boolean },
                         excise: { type: :boolean },
                         vat: { type: :boolean },
                         effective_start_date: { type: :string, nullable: true, format: 'date-time' },
                         effective_end_date: { type: :string, nullable: true, format: 'date-time' },
                       },
                     },
                     relationships: {
                       type: :object,
                       properties: {
                         duty_expression: {
                           type: :object,
                           properties: {
                             data: { type: :object, nullable: true },
                           },
                         },
                         measure_type: {
                           type: :object,
                           properties: {
                             data: { type: :object, nullable: true },
                           },
                         },
                         geographical_area: {
                           type: :object,
                           properties: {
                             data: { type: :object, nullable: true },
                           },
                         },
                         measure_conditions: {
                           type: :object,
                           properties: {
                             data: { type: :array, items: { type: :object } },
                           },
                         },
                         measure_components: {
                           type: :object,
                           properties: {
                             data: { type: :array, items: { type: :object } },
                           },
                         },
                         footnotes: {
                           type: :object,
                           properties: {
                             data: { type: :array, items: { type: :object } },
                           },
                         },
                         order_number: {
                           type: :object,
                           properties: {
                             data: { type: :object, nullable: true },
                           },
                         },
                       },
                     },
                   },
                 },
                 included: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string },
                       attributes: { type: :object },
                     },
                   },
                 },
               }

        let(:measure) { create(:measure) }
        let(:id) { measure.measure_sid }

        run_test!
      end

      response '404', 'measure not found' do
        let(:id) { 99_999_999 }

        run_test!
      end
    end
  end
end

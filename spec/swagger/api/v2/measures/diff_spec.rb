require 'swagger_helper'

RSpec.describe 'Measures Diff', swagger_doc: 'v2/swagger.json', type: :request do
  let(:accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/measures/diff' do
    parameter name: :Accept, getter: :accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :from_date, in: :query, required: true,
              schema: { type: :string, format: 'date' },
              description: 'Start of date range (inclusive, YYYY-MM-DD)'
    parameter name: :to_date, in: :query, required: false,
              schema: { type: :string, format: 'date' },
              description: 'End of date range (inclusive, YYYY-MM-DD; defaults to today)'
    parameter name: :page, in: :query, required: false,
              schema: { type: :integer },
              description: 'Page number (default: 1)'
    parameter name: :per_page, in: :query, required: false,
              schema: { type: :integer },
              description: 'Results per page (default: 25, max: 100)'

    get 'List measure create/update/delete operations for a date range' do
      tags 'Measures'
      produces 'application/json'
      jsonapi_query_parameters(includes: [])
      description 'Returns measure CUD (create/update/delete) operations that occurred within the specified date range. Paginated.'
      operationId 'listMeasuresDiff'

      response '200', 'operations listed' do
        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[measure_operation] },
                       attributes: {
                         type: :object,
                         properties: {
                           measure_sid: { type: :integer, nullable: true },
                           measure_type_id: { type: :string, nullable: true },
                           goods_nomenclature_item_id: { type: :string, nullable: true },
                           geographical_area_id: { type: :string, nullable: true },
                           validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                           validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                           measure_generating_regulation_id: { type: :string, nullable: true },
                           operation_date: { type: :string, nullable: true, format: 'date' },
                           operation: { type: :string, enum: %w[created updated deleted], nullable: true },
                         },
                       },
                     },
                   },
                 },
                 meta: {
                   type: :object,
                   properties: {
                     from_date: { type: :string, format: 'date' },
                     to_date: { type: :string, format: 'date' },
                     pagination: {
                       type: :object,
                       properties: {
                         page: { type: :integer },
                         per_page: { type: :integer },
                         total_count: { type: :integer },
                       },
                     },
                   },
                 },
               }

        let(:from_date) { Date.current.iso8601 }
        let(:to_date) { Date.current.iso8601 }

        before do
          Measure::Operation.insert(
            measure_sid: 90_000_001,
            goods_nomenclature_item_id: '0101210000',
            operation: 'C',
            operation_date: Date.current,
          )
        end

        run_test!
      end

      standard_unprocessable_content_response
      standard_bad_request_response
    end
  end
end

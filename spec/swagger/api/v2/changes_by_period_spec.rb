require 'swagger_helper'

RSpec.describe 'Changes by Period', swagger_doc: 'v2/swagger.json', type: :request do
  let(:accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/changes_by_period' do
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

    get 'List tariff changes for a date range' do
      tags 'Changes'
      produces 'application/json'
      jsonapi_query_parameters(includes: [])
      description 'Returns goods nomenclature changes that occurred within the specified date range. Paginated.'
      operationId 'listChangesByPeriod'

      response '200', 'changes listed' do
        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[change] },
                       attributes: {
                         type: :object,
                         properties: {
                           goods_nomenclature_item_id: { type: :string, nullable: true },
                           goods_nomenclature_sid: { type: :integer, nullable: true },
                           productline_suffix: { type: :string, nullable: true },
                           end_line: { type: :boolean, nullable: true },
                           change_type: { type: :string, nullable: true },
                           change_date: { type: :string, nullable: true, format: 'date' },
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

        before { create(:change, change_date: Date.current) }

        run_test!
      end

      standard_unprocessable_content_response
      standard_bad_request_response
    end
  end
end

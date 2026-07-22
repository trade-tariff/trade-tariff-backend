require 'swagger_helper'

RSpec.describe 'Quota Utilization Summary', swagger_doc: 'v2/swagger.json', type: :request do
  let(:accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/quotas/utilization_summary' do
    parameter name: :Accept, getter: :accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :'filter[measurement_unit_code]', in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by measurement unit code (case-insensitive, e.g. "KGM")'
    parameter name: :'filter[quota_type]', in: :query, required: false,
              schema: { type: :string, enum: %w[licensed fcfs] },
              description: 'Filter by quota type: "licensed" (3rd character of order number is 4) or "fcfs" (first come, first served)'
    parameter name: :page, in: :query, required: false,
              schema: { type: :integer },
              description: 'Page number (default: 1)'
    parameter name: :per_page, in: :query, required: false,
              schema: { type: :integer },
              description: 'Results per page (default: 25, max: 100)'

    get 'Portfolio-level quota utilization summary' do
      tags 'Quotas'
      produces 'application/json'
      jsonapi_query_parameters(includes: [])
      description 'Returns current utilization figures for all quota definitions across the whole tariff. Paginated. Supports filtering by measurement unit or quota type.'
      operationId 'listQuotaUtilizationSummary'

      response '200', 'utilization summary listed' do
        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[quota_utilization_summary] },
                       attributes: {
                         type: :object,
                         properties: {
                           quota_order_number_id: { type: :string, nullable: true },
                           quota_definition_sid: { type: :integer, nullable: true },
                           validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                           validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                           status: { type: :string, nullable: true },
                           measurement_unit_code: { type: :string, nullable: true },
                           quota_type: { type: :string, nullable: true },
                           initial_volume: { type: :number, nullable: true },
                           current_balance: { type: :number, nullable: true },
                           volume_used: { type: :number, nullable: true },
                           utilization_percentage: { type: :number, nullable: true },
                         },
                       },
                     },
                   },
                 },
                 meta: {
                   type: :object,
                   properties: {
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

        before do
          order_number = create(:quota_order_number)
          create(:quota_definition,
                 quota_order_number_id: order_number.quota_order_number_id,
                 quota_order_number_sid: order_number.quota_order_number_sid)
        end

        run_test!
      end
    end
  end
end

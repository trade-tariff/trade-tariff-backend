require 'swagger_helper'

RSpec.describe 'Quota Order Number Utilization', swagger_doc: 'v2/swagger.json', type: :request do
  let(:accept) { 'application/vnd.hmrc.2.0+json' }

  utilization_item_schema = {
    type: :object,
    properties: {
      id: { type: :string },
      type: { type: :string, enum: %w[quota_utilization] },
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
          balance_event_summary: {
            type: :array,
            items: {
              type: :object,
              properties: {
                occurrence_timestamp: { type: :string, nullable: true, format: 'date-time' },
                new_balance: { type: :number, nullable: true },
              },
            },
          },
        },
      },
    },
  }.freeze

  path '/api/quota_order_numbers/{quota_order_number_id}/utilization' do
    parameter name: :Accept, getter: :accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :quota_order_number_id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{6}$' },
              description: 'Six-digit quota order number (e.g. "094011")'
    parameter name: :from_date, in: :query, required: false,
              schema: { type: :string, format: 'date' },
              description: 'Start of reporting period (YYYY-MM-DD; defaults to start of current year)'
    parameter name: :to_date, in: :query, required: false,
              schema: { type: :string, format: 'date' },
              description: 'End of reporting period (YYYY-MM-DD; defaults to today)'

    get 'Quota utilization for a quota order number' do
      tags 'Quotas'
      produces 'application/json'
      jsonapi_query_parameters(includes: [])
      description 'Returns utilization figures for each definition under a quota order number within the requested date range. Includes balance event history.'
      operationId 'getQuotaOrderNumberUtilization'

      response '200', 'utilization data returned' do
        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: {
                   type: :array,
                   items: utilization_item_schema,
                 },
                 meta: {
                   type: :object,
                   properties: {
                     quota_order_number_id: { type: :string },
                     from_date: { type: :string, format: 'date' },
                     to_date: { type: :string, format: 'date' },
                   },
                 },
               }

        let(:quota_order_number_id) { '094011' }

        before do
          order_number = create(:quota_order_number, quota_order_number_id: '094011')
          create(:quota_definition,
                 quota_order_number_id: '094011',
                 quota_order_number_sid: order_number.quota_order_number_sid)
        end

        run_test!
      end

      standard_not_found_response
    end
  end
end

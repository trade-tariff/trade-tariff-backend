require 'swagger_helper'

RSpec.describe 'Quotas', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/uk/api/quotas/search' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :order_number, in: :query, required: false,
              schema: { type: :string, pattern: '^\d{6}$' },
              description: 'Filter by quota order number (exactly 6 digits, e.g. "094011")'
    parameter name: :year, in: :query, required: false,
              schema: { type: :integer },
              description: 'Filter by validity year'
    parameter name: :month, in: :query, required: false,
              schema: { type: :integer },
              description: 'Filter by validity month (1–12)'
    parameter name: :day, in: :query, required: false,
              schema: { type: :integer },
              description: 'Filter by validity day (1–31)'
    parameter name: :page, in: :query, required: false,
              schema: { type: :integer },
              description: 'Page number (default: 1)'

    get 'Search quota definitions' do
      tags 'Quotas'
      produces 'application/json'
      description 'Returns quota definitions matching the search parameters. Results are paginated at 5 per page.'
      operationId 'searchQuotas'

      response '200', 'quotas found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[definition] },
                       attributes: {
                         type: :object,
                         properties: {
                           quota_definition_sid: { type: :integer, nullable: true },
                           quota_order_number_id: { type: :string, nullable: true },
                           initial_volume: { type: :number, nullable: true },
                           validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                           validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                           status: { type: :string, nullable: true },
                           description: { type: :string, nullable: true },
                           balance: { type: :string, nullable: true },
                           measurement_unit: { type: :string, nullable: true },
                           monetary_unit: { type: :string, nullable: true },
                           measurement_unit_qualifier: { type: :string, nullable: true },
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

        let(:qon) { create(:quota_order_number) }
        let(:year) { Time.zone.today.year }

        before do
          create(:quota_definition,
                 :with_quota_balance_events,
                 quota_order_number_sid: qon.quota_order_number_sid,
                 quota_order_number_id: qon.quota_order_number_id,
                 validity_start_date: Date.new(Time.zone.today.year, 1, 1))
        end

        run_test!
      end

      response '400', 'invalid order_number — must be exactly 6 digits' do
        let(:order_number) { 'invalid' }

        run_test!
      end
    end
  end
end

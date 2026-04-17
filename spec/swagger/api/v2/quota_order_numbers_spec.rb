require 'swagger_helper'

RSpec.describe 'Quota Order Numbers', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/uk/api/quota_order_numbers' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'

    get 'List all quota order numbers' do
      tags 'Quotas'
      produces 'application/json'
      description 'Returns all quota order numbers with their current quota definitions.'
      operationId 'listQuotaOrderNumbers'

      response '200', 'quota order numbers listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[quota_order_number] },
                       attributes: {
                         type: :object,
                         properties: {
                           quota_order_number_sid: { type: :integer, nullable: true },
                           validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                           validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                         },
                       },
                     },
                   },
                 },
               }

        before { create(:quota_order_number, :with_quota_definition) }

        run_test!
      end
    end
  end
end

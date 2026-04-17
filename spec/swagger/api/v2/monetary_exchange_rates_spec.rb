require 'swagger_helper'

RSpec.describe 'Monetary Exchange Rates', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/uk/api/monetary_exchange_rates' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'

    get 'List monetary exchange rates' do
      tags 'Exchange Rates'
      produces 'application/json'
      description 'Returns GBP monetary exchange rates from the last 5 years, ordered by validity start date.'
      operationId 'listMonetaryExchangeRates'

      response '200', 'monetary exchange rates listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[monetary_exchange_rate] },
                       attributes: {
                         type: :object,
                         properties: {
                           child_monetary_unit_code: { type: :string, nullable: true },
                           exchange_rate: { type: :string, nullable: true },
                           operation_date: { type: :string, nullable: true, format: 'date' },
                         },
                       },
                     },
                   },
                 },
               }

        before { create(:monetary_exchange_rate) }

        run_test!
      end
    end
  end
end

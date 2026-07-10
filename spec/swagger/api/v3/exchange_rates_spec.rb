require 'swagger_helper'

RSpec.describe 'Exchange Rates V3', swagger_doc: 'v3/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.3.0+json' }

  path '/api/v3/exchange_rates' do
    get 'List exchange rate periods' do
      tags 'Exchange Rates'
      produces 'application/json'
      operationId 'listExchangeRatesV3'
      description 'Returns available exchange rate periods. UK service only. Use the year and type parameters to filter.'

      parameter name: :year, in: :query, schema: { type: :integer, example: 2024 },
                required: false, description: 'Filter by year'
      parameter name: :type, in: :query,
                schema: { type: :string, enum: %w[monthly spot average] },
                required: false, description: 'Exchange rate type'

      response '200', 'exchange rate periods listed' do
        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       year: { type: :integer },
                       month: { type: :integer, nullable: true },
                       has_exchange_rates: { type: :boolean },
                     },
                   },
                 },
                 meta: { '$ref' => '#/components/schemas/meta' },
               }

        before do
          allow(TradeTariffBackend).to receive(:uk?).and_return(true)
          allow(ExchangeRates::PeriodList).to receive(:build).and_return(
            instance_double(
              ExchangeRates::PeriodList,
              exchange_rate_periods: [],
            ),
          )
        end

        run_test!
      end
    end
  end
end

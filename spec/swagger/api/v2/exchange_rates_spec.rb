require 'swagger_helper'

RSpec.describe 'Exchange Rates', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/exchange_rates/{id}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{4}-\d{1,2}$' },
              description: 'Year and month in "YYYY-M" format (e.g. "2024-3")'
    parameter name: 'filter[type]', in: :query, required: true,
              schema: { type: :string, enum: %w[monthly spot average] },
              description: 'Rate type to retrieve'

    get 'Retrieve exchange rates for a period' do
      tags 'Exchange Rates'
      produces 'application/json'
      description 'Returns the exchange rate collection for the specified year, month, and rate type.'
      operationId 'getExchangeRates'

      response '200', 'exchange rates found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     id: { type: :string },
                     type: { type: :string, enum: %w[exchange_rate_collection] },
                     attributes: {
                       type: :object,
                       properties: {
                         year: { type: :integer, nullable: true },
                         month: { type: :integer, nullable: true },
                         type: { type: :string, nullable: true },
                       },
                     },
                     relationships: {
                       type: :object,
                       properties: {
                         exchange_rates: {
                           type: :object,
                           properties: {
                             data: { type: :array, items: { type: :object } },
                           },
                         },
                         exchange_rate_files: {
                           type: :object,
                           properties: {
                             data: { type: :array, items: { type: :object } },
                           },
                         },
                       },
                     },
                   },
                 },
               }

        # ExchangeRateCollection is a non-DB model — stub its build method.
        before do
          allow(ExchangeRates::ExchangeRateCollection)
            .to receive(:build)
            .and_return(build(:exchange_rates_collection, month: 3, year: 2024))
        end

        let(:id) { '2024-3' }
        let(:'filter[type]') { 'monthly' }

        run_test!
      end

      response '404', 'invalid year/month format' do
        let(:id) { 'invalid' }
        let(:'filter[type]') { 'monthly' }

        run_test!
      end
    end
  end

  path '/api/exchange_rates/period_lists/{year}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :year, in: :path, required: true,
              schema: { type: :integer },
              description: 'Four-digit year to filter periods (e.g. 2024)'
    parameter name: 'filter[type]', in: :query, required: true,
              schema: { type: :string, enum: %w[monthly spot average] },
              description: 'Rate type'

    get 'List exchange rate periods for a year' do
      tags 'Exchange Rates'
      produces 'application/json'
      description 'Returns available exchange rate periods for the specified year and type.'
      operationId 'listExchangeRatePeriods'

      response '200', 'period list found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     id: { type: :string },
                     type: { type: :string, enum: %w[exchange_rate_period_list] },
                     attributes: {
                       type: :object,
                       properties: {
                         year: { type: :integer, nullable: true },
                         type: { type: :string, nullable: true },
                       },
                     },
                     relationships: {
                       type: :object,
                       properties: {
                         exchange_rate_periods: {
                           type: :object,
                           properties: {
                             data: { type: :array, items: { type: :object } },
                           },
                         },
                         exchange_rate_years: {
                           type: :object,
                           properties: {
                             data: { type: :array, items: { type: :object } },
                           },
                         },
                       },
                     },
                   },
                 },
               }

        before do
          allow(ExchangeRates::PeriodList)
            .to receive(:build)
            .and_return(build(:period_list, year: 2024, type: 'monthly'))
        end

        let(:year) { 2024 }
        let(:'filter[type]') { 'monthly' }

        run_test!
      end
    end
  end
end

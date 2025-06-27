RSpec.describe ExchangeRates::UpdateCurrencyRatesService do
  let(:xe_api) { instance_double(ExchangeRates::XeApi) }

  let(:response) do
    {
      'to' => [
        { 'quotecurrency' => 'AED', 'mid' => 4.662353708 }, # Has corresponding currency
        { 'quotecurrency' => 'AED', 'mid' => 4.662353708 }, # Has corresponding currency but is duplicated and won't create two
        { 'quotecurrency' => 'EUR', 'mid' => 6.662353708 }, # Has a corresponding currency
        { 'quotecurrency' => 'FGA', 'mid' => 5.662353708 }, # Has no corresponding currency
      ],
    }
  end

  before do
    allow(ExchangeRates::XeApi).to receive(:new).with(date: sample_date).and_return(xe_api)
    allow(xe_api).to receive(:get_all_historic_rates).and_return(response)
  end

  describe '#call' do
    context 'when type is MONTHLY_RATE_TYPE' do
      subject(:service) { described_class.new(date, sample_date, 'monthly') }

      let(:date) { Time.zone.today.next_month }
      let(:expected_rates) do
        [
          {
            currency_code: 'AED',
            validity_start_date: date.beginning_of_month,
            validity_end_date: date.end_of_month,
            rate: 4.662353708,
            rate_type: ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE,
          },
          {
            currency_code: 'EUR',
            validity_start_date: date.beginning_of_month,
            validity_end_date: date.end_of_month,
            rate: 6.662353708,
            rate_type: ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE,
          },
        ].as_json
      end
      let(:sample_date) { Time.zone.today }

      before do
        create(:exchange_rate_country_currency,
               country_code: 'AE',
               country_description: 'UAE',
               currency_description: 'Dirham',
               currency_code: 'AED')
        create(:exchange_rate_country_currency,
               country_code: 'EU',
               country_description: 'Eurozone',
               currency_description: 'Euro',
               currency_code: 'EUR')

        # Only added for the Zimbabwe monkey patch situation
        create(:exchange_rate_country_currency,
               country_code: 'ZW',
               country_description: 'Zimbabwe',
               currency_description: 'Zimbabwe Gold',
               currency_code: 'ZIG')
      end

      it 'only inserts rates that exist as currencies' do
        expect { service.call }.to change(ExchangeRateCurrencyRate, :count).by(2)
      end

      it 'creates the rates specified in the api' do
        service.call

        new_rates = ExchangeRateCurrencyRate.all.map(&:values).as_json

        expect(new_rates).to include_json(expected_rates)
      end
    end

    context 'when type is SPOT_RATE_TYPE' do
      subject(:service) { described_class.new(sample_date, sample_date, 'spot') }

      let(:sample_date) { Time.zone.today }

      let(:expected_rates) do
        [
          {
            currency_code: 'EUR',
            validity_start_date: sample_date.end_of_month,
            validity_end_date: sample_date.end_of_month,
            rate: 6.662353708,
            rate_type: ExchangeRateCurrencyRate::SPOT_RATE_TYPE,
          },
        ].as_json
      end

      it 'creates the rates with correct validity dates for SPOT_RATE_TYPE and filters to save only spot rates' do
        service.call

        new_rates = ExchangeRateCurrencyRate.all.map(&:values).as_json

        expect(new_rates).to include_json(expected_rates)
      end
    end
  end
end

RSpec.describe ExchangeRates::CountryHistories::CreateDayZero do
  subject(:create_day_zero) { described_class.call(path) }

  context 'with valid data' do
    let(:path) { 'spec/fixtures/exchange_rate/day_zero_country_history.csv' }

    it 'will load the day zero data into the db', :aggregate_failures do
      create_day_zero

      expect(ExchangeRateCountryHistory.count).to eq(20)
      expect(ExchangeRateCountryHistory.all.pluck(:start_date)).to all eq(Time.zone.today.beginning_of_day)
      expect(ExchangeRateCountryHistory.all.pluck(:end_date)).to all eq(nil)
      expect(ExchangeRateCountryHistory.find(country: 'Barbados').values.reject{|v| v == :id})
        .to eq({
          :country=>"Barbados",
          :country_code=>"BB",
          :currency_code=>"BBD",
          :currency_description=>"Dollar",
          :start_date=>Time.zone.today.beginning_of_day,
          :end_date=>nil
        })
    end
  end

  context 'with invalid data' do
    context 'when headers are wrong' do
      let(:path) { 'spec/fixtures/exchange_rate/invalid_headers.csv' }

      it 'error generates the csv' do
        expect { create_day_zero }.to raise_error(ArgumentError)
      end
    end

    context 'when file is wrong' do
      let(:path) { 'spec/fixtures/exchange_rate/invalid_data.csv' }

      it 'error generates the csv' do
        expect { create_day_zero }.to raise_error(Sequel::NotNullConstraintViolation)
      end
    end
  end
end

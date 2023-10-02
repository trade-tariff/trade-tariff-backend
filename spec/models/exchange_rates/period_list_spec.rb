RSpec.describe ExchangeRates::PeriodList do
  let(:year) { 2020 }
  let(:months) { [1, 2, 3] }

  describe '#id' do
    subject(:period_list) { build(:period_list) }

    it 'returns the correct id' do
      expect(period_list.id).to be_present
    end
  end

  describe '#exchange_rate_year_ids' do
    subject(:period_list) { build(:period_list) }

    it 'returns the ids of exchange rate years' do
      expect(period_list.exchange_rate_year_ids).to be_empty
    end
  end

  describe '#exchange_rate_period_ids' do
    subject(:period_list) { build(:period_list) }

    it 'returns the ids of exchange rate periods' do
      expect(period_list.exchange_rate_period_ids).to be_empty
    end
  end

  describe '.build' do
    subject(:period_list) { described_class.build(ExchangeRateCurrencyRate::SCHEDULED_RATE_TYPE, year) }

    it 'builds a period list with exchange rate periods and years' do
      expect(period_list).to be_an_instance_of(described_class)
    end

    it 'sets the year correctly' do
      expect(period_list.year).to eq(year)
    end

    it 'initializes exchange rate periods to an empty array' do
      expect(period_list.exchange_rate_periods).to be_empty
    end

    it 'initializes exchange rate years to an empty array' do
      expect(period_list.exchange_rate_years).to be_empty
    end
  end

  describe '.exchange_rate_years' do
    subject(:exchange_rate_years) do
      described_class.exchange_rate_years(ExchangeRateCurrencyRate::SCHEDULED_RATE_TYPE)
    end

    let(:years) { [2022, 2021, 2020] }

    before do
      allow(ExchangeRateCurrencyRate).to receive(:all_years).and_return(years)
    end

    it 'calls ExchangeRates::PeriodYear.build with the correct arguments' do
      allow(ExchangeRates::PeriodYear).to receive(:wrap).with(years).and_return([])
      exchange_rate_years
    end

    it 'returns an array' do
      expect(exchange_rate_years).to be_an(Array)
    end

    it 'returns an array of ExchangeRates::PeriodYear instances' do
      expect(exchange_rate_years).to all(be_an_instance_of(ExchangeRates::PeriodYear))
    end
  end
end

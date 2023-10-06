RSpec.describe ExchangeRates::PeriodList do
  let(:year) { 2020 }

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
    subject(:period_list) { described_class.build(ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE, year) }

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

    context 'when year is nil' do
      let(:year) { nil }

      it 'calls max_year' do
        allow(ExchangeRateCurrencyRate).to receive(:max_year)

        period_list.exchange_rate_periods

        expect(ExchangeRateCurrencyRate).to have_received(:max_year).with('monthly')
      end
    end
  end
end

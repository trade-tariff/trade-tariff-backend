RSpec.describe ExchangeRates::PeriodYear do
  describe '.build' do
    subject(:period_years) { described_class.build(years) }

    let(:years) { [2020, 2021, 2022] }

    it 'builds an array of period years' do
      expect(period_years).to be_an(Array)
    end

    it 'contains 3 period years' do
      expect(period_years.size).to eq(3)
    end

    it 'builds period years with correct year' do
      years.each_with_index do |year, index|
        expect(period_years[index].year).to eq(year)
      end
    end
  end

  describe '#id' do
    subject(:period_year) { build(:period_year, year: year) }

    let(:year) { 2020 }

    it 'returns the correct id' do
      expect(period_year.id).to eq('2020-exchange_rate_year')
    end
  end
end

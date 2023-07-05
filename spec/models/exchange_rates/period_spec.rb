RSpec.describe ExchangeRates::Period do
  describe '#id' do
    let(:period) { build(:exchange_rates_period) }

    before do
      period.year = 2022
      period.month = 3
    end

    it 'returns the formatted period ID' do
      expect(period.id).to eq('2022-3-exchange_rate_period')
    end
  end

  describe '.build' do
    let(:year) { 2022 }
    let(:month) { 3 }
    let(:period) { described_class.build(month, year) }

    it 'builds a period' do
      expect(period).to be_a(described_class)
    end

    it 'builds a period with correct month' do
      expect(period.month).to eq(month)
    end

    it 'builds a period with correct year' do
      expect(period.year).to eq(year)
    end
  end

  describe '.wrap' do
    let(:year) { 2022 }
    let(:months) { [1, 2, 3] }
    let(:periods) { described_class.wrap(months, year) }

    it 'builds an array of periods' do
      expect(periods).to be_an(Array)
    end

    it 'builds an array of 3 periods' do
      expect(periods.size).to eq(3)
    end

    it 'builds periods with correct month' do
      periods.each do |period|
        expect(period.month).to be_in(months)
      end
    end

    it 'builds periods with correct year' do
      periods.each do |period|
        expect(period.year).to eq(year)
      end
    end
  end
end

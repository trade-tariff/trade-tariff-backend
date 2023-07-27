RSpec.describe ExchangeRates::Period do
  let(:year) { 2022 }
  let(:month) { 3 }
  let(:period) { described_class.build(month, year) }

  describe '#id' do
    it 'returns the formatted period ID' do
      expect(period.id).to eq('2022-3-exchange_rate_period')
    end
  end

  describe '#file_ids' do
    context 'without files' do
      it 'returns empty array' do
        expect(period.file_ids).to be_empty
      end
    end

    context 'with files' do
      before do
        create(:exchange_rate_file, period_year: year, period_month: month)
      end

      it 'returns the ids of associated exchange rate files' do
        expect(period.file_ids).to eq([period.files.first.id])
      end
    end
  end

  describe '.build' do
    context 'without files' do
      it 'does not load any associated files' do
        expect(period.files.count).to eq(0)
      end
    end

    context 'with files' do
      before do
        create(:exchange_rate_file, period_year: year, period_month: month)
        create(:exchange_rate_file, period_year: year, period_month: month)
      end

      it 'builds a period' do
        expect(period).to be_a(described_class)
      end

      it 'builds a period with correct month' do
        expect(period.month).to eq(month)
      end

      it 'builds a period with correct year' do
        expect(period.year).to eq(year)
      end

      it 'loads associated files' do
        expect(period.files.count).to eq(2)
      end
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

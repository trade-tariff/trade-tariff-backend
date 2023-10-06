RSpec.describe ExchangeRates::Period do
  describe '#id' do
    subject(:id) { build(:exchange_rates_period, year: '2022', month: '3').id }

    it { is_expected.to eq('2022-3-exchange_rate_period') }
  end

  describe '.build' do
    let(:period) do
      described_class.build(
        {
          month: '3',
          year: '2022',
          has_exchange_rates: true,
        },
        ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE,
      )
    end

    context 'without files' do
      it { expect(period.files).to be_empty }
    end

    context 'with files' do
      before do
        create(:exchange_rate_file, period_year: '2022', period_month: '3', type: 'monthly_csv')
      end

      it { expect(period).to be_a(described_class) }
      it { expect(period).to have_attributes(month: '3', year: '2022') }
      it { expect(period.files.pluck(:type)).to eq(%w[monthly_csv]) }
    end
  end

  describe '.wrap' do
    let(:year) { 2022 }
    let(:month) { 1 }
    let(:periods) do
      described_class.wrap(
        [{
          month:,
          year:,
          has_exchange_rates: true,
        }],
        ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE,
      )
    end

    it 'builds an array of periods' do
      expect(periods).to be_an(Array)
    end

    it 'builds an array of one period' do
      expect(periods.size).to eq(1)
    end

    it 'builds periods with correct month' do
      periods.each do |period|
        expect(period.month).to be(month)
      end
    end

    it 'builds periods with correct year' do
      periods.each do |period|
        expect(period.year).to eq(year)
      end
    end
  end
end

require 'csv'

RSpec.describe ExchangeRateCurrencyRate do
  let(:january) { described_class.where(validity_start_date: '2020-01-01', validity_end_date: '2020-01-31') }
  let(:february) { described_class.where(validity_start_date: '2020-02-01', validity_end_date: '2020-02-29') }
  let(:aed) { january.where(currency_code: 'AED').take }

  describe '.for_month' do
    subject(:for_month) { described_class.for_month(1, 2020) }

    before do
      # scheduled and within month and year so in scope
      create(
        :exchange_rate_currency_rate,
        :scheduled_rate,
        currency_code: 'YYY',
        validity_start_date: '2020-01-02', # in scope
      )
      create(
        :exchange_rate_currency_rate,
        :scheduled_rate,
        currency_code: 'XXX',
        validity_start_date: '2020-01-01', # in scope
      )

      # non-scheduled so filtered out
      create(
        :exchange_rate_currency_rate,
        :spot_rate,
        currency_code: 'XXX',
        validity_start_date: '2020-01-01', # in scope
      )
      # scheduled but not within month and year so filtered out
      create(
        :exchange_rate_currency_rate,
        :scheduled_rate,
        currency_code: 'XXX',
        validity_start_date: '2020-03-01', # not in scope
      )
    end

    it { is_expected.to all(be_a(described_class)) }
    it { expect(for_month.pluck(:validity_start_date)).to eq(['2020-01-01'.to_date, '2020-01-02'.to_date]) }
    it { expect(for_month.pluck(:currency_code)).to eq(%w[XXX YYY]) }
    it { expect(for_month.pluck(:rate_type)).to eq(%w[scheduled scheduled]) }
  end

  describe '.all_years' do
    before do
      create(:exchange_rate_currency_rate, validity_start_date: '2020-01-01')
      create(:exchange_rate_currency_rate, validity_start_date: '2021-01-01')
    end

    it 'returns the distinct years in descending order' do
      expect(described_class.all_years).to eq([2021, 2020])
    end
  end

  describe '.max_year' do
    before do
      create(:exchange_rate_currency_rate, validity_start_date: '2020-01-01')
      create(:exchange_rate_currency_rate, validity_start_date: '2021-01-01')
    end

    it 'returns the maximum year from the validity start dates' do
      expect(described_class.max_year).to eq(2021)
    end
  end

  describe '.months_for_year' do
    before do
      create(:exchange_rate_currency_rate, validity_start_date: '2020-01-01')
      create(:exchange_rate_currency_rate, validity_start_date: '2020-07-01')
    end

    it 'returns the distinct months for the given year in descending order' do
      expect(described_class.months_for_year(2020)).to eq([7, 1])
    end
  end

  describe '#scheduled_rate?' do
    context 'when the validity_start_date is first of the month and the validity_end_date is the end of the month' do
      subject(:currency_rate) do
        build(
          :exchange_rate_currency_rate,
          rate_type: 'scheduled',
          validity_start_date: Date.new(2020, 1, 1),
          validity_end_date: Date.new(2020, 1, 31),
        )
      end

      it { is_expected.to be_scheduled_rate }
    end

    shared_examples_for 'an non scheduled rate' do |validity_start_date, validity_end_date|
      subject(:currency_rate) do
        build(
          :exchange_rate_currency_rate,
          validity_start_date:,
          validity_end_date:,
        )
      end

      let(:validity_start_date) { validity_start_date }
      let(:validity_end_date) { validity_end_date }

      it { is_expected.not_to be_scheduled_rate }
    end

    it_behaves_like 'an non scheduled rate', Date.new(2020, 1, 1), Date.new(2020, 1, 30) # not end of month
    it_behaves_like 'an non scheduled rate', Date.new(2020, 1, 1), nil # no end date
    it_behaves_like 'an non scheduled rate', Date.new(2020, 1, 2), Date.new(2020, 1, 31) # not start of month
    it_behaves_like 'an non scheduled rate', nil, Date.new(2020, 1, 31) # no start date
  end

  describe '#spot_rate?' do
    subject(:currency_rate) { build(:exchange_rate_currency_rate, :spot_rate) }

    it { is_expected.to be_spot_rate }

    context 'when validity_end_date is present' do
      before { currency_rate.validity_end_date = Date.new(2022, 12, 31) }

      it { is_expected.not_to be_spot_rate }
    end

    context 'when validity_start_date is not the last day of the month' do
      before { currency_rate.validity_start_date = Date.new(2022, 12, 15) }

      it { is_expected.not_to be_spot_rate }
    end

    context 'when rate_type is not "spot"' do
      subject(:currency_rate) { build(:exchange_rate_currency_rate) }

      it { is_expected.not_to be_spot_rate }
    end
  end

  describe '.scheduled' do
    before do
      create(:exchange_rate_currency_rate, :scheduled_rate)
      create(:exchange_rate_currency_rate, :spot_rate)
    end

    it 'returns only the rates with rate_type "scheduled"' do
      expect(described_class.scheduled).to all(be_scheduled_rate)
    end
  end

  describe '.spot' do
    before do
      create(:exchange_rate_currency_rate, :spot_rate)
      create(:exchange_rate_currency_rate, :scheduled_rate)
    end

    it 'returns only the rates with rate_type "spot"' do
      expect(described_class.spot).to all(be_spot_rate)
    end
  end

  describe '.by_year' do
    before do
      create(:exchange_rate_currency_rate, validity_start_date: '2020-01-01')
      create(:exchange_rate_currency_rate, validity_start_date: '2021-01-01')
      create(:exchange_rate_currency_rate, validity_start_date: '2023-01-01')
      create(:exchange_rate_currency_rate, validity_start_date: '2023-02-01')
    end

    it { expect(described_class.by_year(2023).count).to eq(2) }

    it { expect(described_class.by_year(nil)).to be_nil }
  end
end

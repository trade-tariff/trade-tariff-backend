RSpec.describe ExchangeRateCurrencyRate do
  describe '.all_years' do
    before do
      create(:exchange_rate_currency_rate, validity_start_date: '2020-01-01')
      create(:exchange_rate_currency_rate, validity_start_date: '2021-01-01')
    end

    it 'returns the distinct years in descending order' do
      expect(described_class.all_years(ExchangeRateCurrencyRate::SCHEDULED_RATE_TYPE)).to eq([2021, 2020])
    end
  end

  describe '.max_year' do
    before do
      create(:exchange_rate_currency_rate, validity_start_date: '2020-01-01')
      create(:exchange_rate_currency_rate, validity_start_date: '2021-01-01')
    end

    it 'returns the maximum year from the validity start dates' do
      expect(described_class.max_year('scheduled')).to eq(2021)
    end
  end

  describe '.months_for_year' do
    subject(:result) { described_class.months_for_year(2020, ExchangeRateCurrencyRate::SCHEDULED_RATE_TYPE) }

    before do
      create(
        :exchange_rate_currency_rate,
        :scheduled_rate,
        validity_start_date: '2020-01-01',
      )
      create(
        :exchange_rate_currency_rate,
        :scheduled_rate,
        validity_start_date: '2020-07-01',
      )
    end

    it { expect(result).to eq([7, 1]) }
  end

  describe '.for_month' do
    subject(:for_month) { described_class.for_month(1, 2020, ExchangeRateCurrencyRate::SCHEDULED_RATE_TYPE) }

    before do
      create(:exchange_rate_currency_rate, :scheduled_rate, currency_code: 'YYY', validity_start_date: '2020-01-01')
      create(:exchange_rate_currency_rate, :scheduled_rate, currency_code: 'XXX', validity_start_date: '2020-01-31')
      create(:exchange_rate_currency_rate, :spot_rate, validity_start_date: '2020-02-02')
    end

    it { is_expected.to all(be_a(described_class)) }
    it { expect(for_month.pluck(:validity_start_date)).to eq(['2020-01-31'.to_date, '2020-01-01'.to_date]) }
    it { expect(for_month.pluck(:currency_code)).to eq(%w[XXX YYY]) }
    it { expect(for_month.pluck(:rate_type)).to all(eq('scheduled')) }
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

  describe '.with_applicable_date' do
    subject(:dataset) { described_class.with_applicable_date }

    before do
      create(
        :exchange_rate_currency_rate,
        :scheduled_rate,
        validity_start_date: '2020-03-01',
        validity_end_date: '2020-03-31',
      )
      create(
        :exchange_rate_currency_rate,
        :spot_rate,
        validity_start_date: '2021-01-01',
        validity_end_date: nil,
      )
      create(
        :exchange_rate_currency_rate,
        :average_rate,
        validity_start_date: '2019-03-31',
        validity_end_date: '2020-03-31',
      )
    end

    it 'picks the right applicable date for the given rate type' do
      expected = [
        ['scheduled', '2020-03-01'.to_date], # picks start date
        ['spot', '2021-01-01'.to_date],      # picks start date
        ['average', '2020-03-31'.to_date],   # picks end date
      ]

      expect(dataset.pluck(:rate_type, :applicable_date)).to eq(expected)
    end
  end

  describe '.with_applicable_year' do
    subject(:dataset) { described_class.with_applicable_date.with_applicable_year }

    before do
      create(:exchange_rate_currency_rate, validity_start_date: '2020-01-01')
      create(:exchange_rate_currency_rate, validity_start_date: '2021-01-01')
    end

    it { expect(dataset.map(&:values)).to eq([{ year: 2020 }, { year: 2021 }]) }
  end

  describe '.with_applicable_month' do
    subject(:dataset) { described_class.with_applicable_date.with_applicable_month }

    before do
      create(:exchange_rate_currency_rate, validity_start_date: '2020-01-01')
      create(:exchange_rate_currency_rate, validity_start_date: '2020-12-12')
    end

    it { expect(dataset.map(&:values)).to eq([{ month: 1 }, { month: 12 }]) }
  end

  describe '.by_type' do
    subject(:dataset) { described_class.by_type('scheduled') }

    before do
      create(:exchange_rate_currency_rate, rate_type: 'scheduled')
      create(:exchange_rate_currency_rate, rate_type: 'foo')
    end

    it { expect(dataset.pluck(:rate_type)).to eq(%w[scheduled]) }
  end

  describe '.by_year' do
    subject(:dataset) { described_class.with_applicable_date.by_year(2023) }

    before do
      create(:exchange_rate_currency_rate, validity_start_date: '2020-01-01')
      create(:exchange_rate_currency_rate, validity_start_date: '2021-01-01')
      create(:exchange_rate_currency_rate, validity_start_date: '2023-01-01')
      create(:exchange_rate_currency_rate, validity_start_date: '2023-02-01')
    end

    it { expect(dataset.count).to eq(2) }
  end

  describe '.by_month_and_year' do
    subject(:result) { described_class.with_applicable_date.by_month_and_year(1, 2020) }

    before do
      create(:exchange_rate_currency_rate, validity_start_date: '2021-01-31') # excluded
      create(:exchange_rate_currency_rate, validity_start_date: '2020-01-31') # included
      create(:exchange_rate_currency_rate, validity_start_date: '2020-01-21') # included
    end

    it { expect(result.pluck(:validity_start_date)).to eq([Date.parse('2020-01-31'), Date.parse('2020-01-21')]) }
  end
end

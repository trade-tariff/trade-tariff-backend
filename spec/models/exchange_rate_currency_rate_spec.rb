RSpec.describe ExchangeRateCurrencyRate do
  describe '.all_years' do
    before do
      create(:exchange_rate_currency_rate, validity_start_date: '2020-01-01')
      create(:exchange_rate_currency_rate, validity_start_date: '2021-01-01')
    end

    it 'returns the distinct years in descending order' do
      expect(described_class.all_years(ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE)).to eq([2021, 2020])
    end
  end

  describe '.max_year' do
    before do
      create(:exchange_rate_currency_rate, validity_start_date: '2020-01-01')
      create(:exchange_rate_currency_rate, validity_start_date: '2021-01-01')
    end

    it { expect(described_class.max_year('monthly')).to eq(2021) }
  end

  describe '.months_for_year' do
    subject(:result) { described_class.months_for(ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE, 2020) }

    before do
      create(
        :exchange_rate_currency_rate,
        :monthly_rate,
        validity_start_date: '2020-01-01',
      )
      create(
        :exchange_rate_currency_rate,
        :monthly_rate,
        validity_start_date: '2020-07-01',
      )
    end

    it { expect(result).to eq([[7, 2020], [1, 2020]]) }
  end

  describe '.for_month' do
    subject(:for_month) { described_class.for_month(1, 2020, ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE) }

    before do
      create(:exchange_rate_currency_rate, :monthly_rate, currency_code: 'YYY', validity_start_date: '2020-01-01')
      create(:exchange_rate_currency_rate, :monthly_rate, currency_code: 'XXX', validity_start_date: '2020-01-31')
      create(:exchange_rate_currency_rate, :monthly_rate, currency_code: 'ZZZ', validity_start_date: '2020-01-31')
      create(:exchange_rate_currency_rate, :spot_rate, validity_start_date: '2020-02-02')
      create(:exchange_rate_country_currency, currency_code: 'XXX', validity_start_date: '2020-01-01')
      create(:exchange_rate_country_currency, currency_code: 'YYY', validity_start_date: '2020-01-01')
      create(:exchange_rate_country_currency, currency_code: 'ZZZ', validity_start_date: '2019-12-01', validity_end_date: '2019-12-31')
      create(:exchange_rate_country_currency, currency_code: 'AED', validity_start_date: '2020-01-01')
    end

    it { is_expected.to all(be_a(described_class)) }
    it { expect(for_month.pluck(:validity_start_date)).to eq(['2020-01-31'.to_date, '2020-01-01'.to_date]) }
    it { expect(for_month.pluck(:currency_code)).to eq(%w[XXX YYY]) }
    it { expect(for_month.pluck(:rate_type)).to all(eq('monthly')) }
  end

  describe '.with_applicable_date' do
    subject(:dataset) { described_class.with_applicable_date }

    before do
      create(
        :exchange_rate_currency_rate,
        :monthly_rate,
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
        ['monthly', '2020-03-01'.to_date], # picks start date
        ['spot', '2021-01-01'.to_date],      # picks start date
        ['average', '2020-03-31'.to_date],   # picks end date
      ]

      expect(dataset.pluck(:rate_type, :applicable_date)).to eq(expected)
    end
  end

  describe '.with_exchange_rate_country_currency' do
    subject(:dataset) { described_class.with_exchange_rate_country_currency }

    context 'when there are no matching exchange rates' do
      before do
        create(:exchange_rate_country_currency, validity_start_date: '2020-01-01')
      end

      it { expect(dataset).to be_empty }
    end

    context 'when there are no matching country currencies' do
      before do
        create(:exchange_rate_currency_rate, validity_start_date: '2020-01-01')
      end

      it { expect(dataset).to be_empty }
    end

    # exchange rate              |-------|
    # country  currency |-------|
    context 'when exchange rate is after the country currency' do
      before do
        create(
          :exchange_rate_country_currency,
          validity_start_date: '2020-01-01',
          validity_end_date: '2020-01-31',
        )
        create(
          :exchange_rate_currency_rate,
          validity_start_date: '2020-02-01',
          validity_end_date: '2020-02-29',
        )
      end

      it { expect(dataset).to be_empty }
    end

    # exchange rate     |-------|
    # country  currency          |-------|
    context 'when the country currency is after the exchange rate' do
      before do
        create(
          :exchange_rate_country_currency,
          currency_code: 'EUR',
          validity_start_date: '2020-02-01',
          validity_end_date: '2020-02-29',
        )
        create(
          :exchange_rate_currency_rate,
          currency_code: 'EUR',
          validity_start_date: '2020-01-01',
          validity_end_date: '2020-01-31',
        )
      end

      it { expect(dataset).to be_empty }
    end

    # exchange rate     |-------|
    # country  currency   |-----|
    context 'when the exchange rate starts before the country currency' do
      before do
        create(
          :exchange_rate_country_currency,
          currency_code: 'EUR',
          validity_start_date: '2020-01-01',
          validity_end_date: '2020-01-31',
        )
        create(
          :exchange_rate_currency_rate,
          currency_code: 'EUR',
          validity_start_date: '2019-12-01',
          validity_end_date: '2020-01-31',
        )
      end

      it { expect(dataset).not_to be_empty }
    end

    # exchange rate     |---------|
    # country  currency |-------|
    context 'when the exchange rate ends after the country currency' do
      before do
        create(
          :exchange_rate_country_currency,
          currency_code: 'EUR',
          validity_start_date: '2020-01-01',
          validity_end_date: '2020-01-31',
        )
        create(
          :exchange_rate_currency_rate,
          currency_code: 'EUR',
          validity_start_date: '2020-01-01',
          validity_end_date: '2020-02-29',
        )
      end

      it { expect(dataset).not_to be_empty }
    end

    # exchange rate     |---------|
    # country  currency   |-----|
    context 'when the exchange rate entirely contains the country currency' do
      before do
        create(
          :exchange_rate_country_currency,
          currency_code: 'EUR',
          validity_start_date: '2020-01-01',
          validity_end_date: '2020-01-31',
        )
        create(
          :exchange_rate_currency_rate,
          currency_code: 'EUR',
          validity_start_date: '2019-12-01',
          validity_end_date: '2020-02-29',
        )
      end

      it { expect(dataset).not_to be_empty }
    end

    # exchange rate       |---|
    # country  currency |-------|
    context 'when the country currency entirely contains the exchange rate' do
      before do
        create(
          :exchange_rate_country_currency,
          currency_code: 'EUR',
          validity_start_date: '2019-12-01',
          validity_end_date: '2020-02-29',
        )
        create(
          :exchange_rate_currency_rate,
          currency_code: 'EUR',
          validity_start_date: '2020-01-01',
          validity_end_date: '2020-01-31',
        )
      end

      it { expect(dataset).not_to be_empty }
    end

    # exchange rate       |-----|
    # country  currency   |-----|
    # country  currency     |---|
    context 'when the exchange rate overlaps multiple of the same country currencies' do
      before do
        create(
          :exchange_rate_country_currency,
          currency_code: 'EUR',
          country_code: 'Denmark',
          validity_start_date: '2020-01-01',
          validity_end_date: '2020-01-31',
        )
        create(
          :exchange_rate_country_currency,
          currency_code: 'EUR',
          country_code: 'Denmark',
          validity_start_date: '2020-01-02',
          validity_end_date: '2020-01-31',
        )

        create(
          :exchange_rate_currency_rate,
          currency_code: 'EUR',
          validity_start_date: '2020-01-01',
          validity_end_date: '2020-01-31',
        )
      end

      it { expect(dataset.pluck(:country_code)).to eq(%w[Denmark Denmark]) }
    end

    # exchange rate       |-----|
    # country  currency   |...
    context 'when the country currency has no end date' do
      before do
        create(
          :exchange_rate_country_currency,
          currency_code: 'EUR',
          validity_start_date: '2020-01-01',
          validity_end_date: nil,
        )
        create(
          :exchange_rate_currency_rate,
          currency_code: 'EUR',
          validity_start_date: '2020-01-01',
          validity_end_date: '2020-01-31',
        )
      end

      it { expect(dataset).not_to be_empty }
    end

    context 'when multiple countries share the same currency code' do
      before do
        create(
          :exchange_rate_country_currency,
          validity_start_date: '2020-01-01',
          validity_end_date: '2020-01-31',
          country_code: 'FR',
          currency_code: 'EUR',
          country_description: 'France',
          currency_description: 'Euro',
        )

        create(
          :exchange_rate_country_currency,
          validity_start_date: '2020-01-01',
          validity_end_date: '2020-01-31',
          country_code: 'IT',
          currency_code: 'EUR',
          country_description: 'Italy',
          currency_description: 'Euro',
        )

        create(
          :exchange_rate_currency_rate,
          :monthly_rate,
          currency_code: 'EUR',
          validity_start_date: '2020-01-01',
          validity_end_date: '2020-01-31',
        )
      end

      it 'returns the exchange rate for each country' do
        expect(dataset.pluck(:country_code)).to include('FR', 'IT')
      end
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

  describe '.by_type' do
    subject(:dataset) { described_class.by_type('monthly') }

    before do
      create(:exchange_rate_currency_rate, :monthly_rate, currency_code: 'XXX')
      create(:exchange_rate_currency_rate, :spot_rate, currency_code: 'YYY')
    end

    it { expect(dataset.pluck(:rate_type)).to eq(%w[monthly]) }
  end

  describe '.by_currency' do
    subject(:dataset) { described_class.by_currency(currency_code) }

    before do
      create(:exchange_rate_currency_rate, :with_usa)
      create(:exchange_rate_currency_rate, :with_eur)
    end

    context 'when currency code is lower case' do
      let(:currency_code) { 'usd' }

      it { expect(dataset.pluck(:currency_code)).to eq(%w[USD]) }
    end
  end

  describe '.monthly_by_currency_last_year' do
    subject(:dataset) { described_class.monthly_by_currency_last_year(currency_code, today) }

    let(:today) { Time.zone.today }
    let(:currency_code) { 'usd' }

    before do
      create(:exchange_rate_currency_rate, :monthly_rate, :with_usa,
             validity_start_date: today.beginning_of_month + 1.month,
             validity_end_date: today.end_of_month + 1.month)
      create(:exchange_rate_currency_rate, :monthly_rate, :with_usa,
             validity_start_date: today.end_of_month,
             validity_end_date: today.end_of_month)
      create(:exchange_rate_currency_rate, :monthly_rate, :with_usa,
             validity_start_date: today.beginning_of_month - 11.months,
             validity_end_date: today.end_of_month - 11.months)
      create(:exchange_rate_currency_rate, :monthly_rate, :with_usa,
             validity_start_date: today.end_of_month - 12.months,
             validity_end_date: today.end_of_month - 12.months)
      create(:exchange_rate_currency_rate, :monthly_rate, :with_eur,
             validity_start_date: today.beginning_of_month,
             validity_end_date: today.end_of_month)
    end

    it 'returns the correct results', :aggregate_failures do
      expect(dataset.count).to eq(2)
      expect(dataset.pluck(:currency_code).uniq).to eq(%w[USD])
    end
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

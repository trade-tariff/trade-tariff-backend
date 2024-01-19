RSpec.describe ExchangeRates do
  let(:eur) { create(:exchange_rate_country_currency, :eu) }
  let(:usa) { create(:exchange_rate_country_currency, :us) }

  describe 'Remove old monthly rates' do
    subject(:remove_old_monthly_rates) { Rake::Task['exchange_rates:remove_old_monthly_rates'].invoke }

    # Set env variables
    let(:month_start_period) { '2' }
    let(:year_start_period) { '2021' }
    let(:month_end_period) { '10' }
    let(:year_end_period) { '2022' }
    let(:currency_code) { 'EUR' }
    let(:period_start) { Date.new(year_start_period.to_i, month_start_period.to_i) }
    let(:period_end) { Date.new(year_end_period.to_i, month_end_period.to_i) }

    before do
      # different_currency_exchange_rate
      create(:exchange_rate_currency_rate,
             currency_code: usa.currency_code,
             validity_start_date: period_start,
             validity_end_date: period_start.end_of_month)

      # before_period_exchange_rate
      create(:exchange_rate_currency_rate,
             currency_code: eur.currency_code,
             validity_start_date: period_start - 1.month,
             validity_end_date: (period_start - 1.month).end_of_month)

      # after_period_exchange_rate
      create(:exchange_rate_currency_rate,
             currency_code: eur.currency_code,
             validity_start_date: period_end + 1.month,
             validity_end_date: (period_end + 1.month).end_of_month)

      # within_period_exchange_rate_beginning
      create(:exchange_rate_currency_rate,
             currency_code: eur.currency_code,
             validity_start_date: period_start,
             validity_end_date: period_start.end_of_month)

      # within_period_exchange_rate_end
      create(:exchange_rate_currency_rate,
             currency_code: eur.currency_code,
             validity_start_date: period_end,
             validity_end_date: period_end.end_of_month)

      # within_period_exchange_rate_end_wrong_type
      create(:exchange_rate_currency_rate,
             :average_rate,
             currency_code: eur.currency_code,
             validity_start_date: period_end,
             validity_end_date: period_end.end_of_month)

      # deleted_exchange_rate_file_beginning
      create(:exchange_rate_file,
             period_month: month_start_period,
             period_year: year_start_period)

      # deleted_exchange_rate_file_end
      create(:exchange_rate_file,
             period_month: month_end_period,
             period_year: year_end_period)

      # non_deleted_exchange_rate_file_beginning
      create(:exchange_rate_file,
             period_month: month_start_period.to_i - 1,
             period_year: year_start_period.to_i)

      # non_deleted_exchange_rate_file_end
      create(:exchange_rate_file,
             period_month: month_end_period.to_i + 1,
             period_year: year_end_period.to_i)

      ENV['MONTH_START_PERIOD'] = month_start_period
      ENV['YEAR_START_PERIOD'] = year_start_period
      ENV['MONTH_END_PERIOD'] = month_end_period
      ENV['YEAR_END_PERIOD'] = year_end_period
      ENV['CURRENCY_CODE'] = currency_code
    end

    it 'deletes the correct exchange rates', :aggregate_failures do
      expect(ExchangeRateCurrencyRate.where(rate_type: ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE).count).to eq(5)
      expect(ExchangeRateCurrencyRate.count).to eq(6)
      expect(ExchangeRateFile.count).to eq(4)
      remove_old_monthly_rates

      expect(ExchangeRateCurrencyRate.count).to eq(4)
      expect(ExchangeRateCurrencyRate.where(rate_type: ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE).count).to eq(3)
      expect(ExchangeRateFile.count).to eq(2)
    end
  end

  describe 'Rebuild monthly rates' do
    subject(:rebuild_monthly_rates) { Rake::Task['exchange_rates:rebuild_monthly_rates'].invoke }

    # Set env variables
    let(:month_start_period) { '2' }
    let(:year_start_period) { '2021' }
    let(:month_end_period) { '3' }
    let(:year_end_period) { '2021' }

    before do
      ENV['MONTH_START_PERIOD'] = month_start_period
      ENV['YEAR_START_PERIOD'] = year_start_period
      ENV['MONTH_END_PERIOD'] = month_end_period
      ENV['YEAR_END_PERIOD'] = year_end_period

      create(:exchange_rate_currency_rate,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2021, 1, 1),
             validity_end_date: Date.new(2021, 1, 31))

      create(:exchange_rate_currency_rate,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2021, 1, 1),
             validity_end_date: Date.new(2021, 1, 31))

      create(:exchange_rate_currency_rate,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2021, 2, 1),
             validity_end_date: Date.new(2021, 2, 28))

      create(:exchange_rate_currency_rate,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2021, 2, 1),
             validity_end_date: Date.new(2021, 2, 28))

      create(:exchange_rate_currency_rate,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2021, 3, 1),
             validity_end_date: Date.new(2021, 3, 31))

      create(:exchange_rate_currency_rate,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2021, 3, 1),
             validity_end_date: Date.new(2021, 3, 31))

      create(:exchange_rate_file, period_month: 1, period_year: 2021)
      create(:exchange_rate_file, period_month: 1, period_year: 2021, type: 'monthly_xml', format: 'xml')
      create(:exchange_rate_file, period_month: 1, period_year: 2021, type: 'monthly_csv_hmrc')
    end

    it 'deletes the correct exchange rates', :aggregate_failures do
      expect(ExchangeRateCurrencyRate.count).to eq(6)
      expect(ExchangeRateFile.count).to eq(3)
      rebuild_monthly_rates

      expect(ExchangeRateCurrencyRate.count).to eq(6)
      expect(ExchangeRateFile.count).to eq(9)

      expect(ExchangeRateFile
        .where(period_month: 2, period_year: 2021)
        .all? { |file| file.publication_date == Date.new(2021, 1, 27) }).to eq(true)
      expect(ExchangeRateFile
        .where(period_month: 3, period_year: 2021)
        .all? { |file| file.publication_date == Date.new(2021, 2, 24) }).to eq(true)
    end
  end

  describe 'Remove average rates' do
    subject(:remove_old_average_rates) { Rake::Task['exchange_rates:remove_old_average_rates'].invoke }

    # Set env variables
    let(:avg_period_month) { '12' }
    let(:avg_period_year) { '2023' }

    before do
      ENV['AVG_PERIOD_MONTH'] = avg_period_month
      ENV['AVG_PERIOD_YEAR'] = avg_period_year

      create(:exchange_rate_currency_rate,
             :average_rate,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2023, 0o3, 1),
             validity_end_date: Date.new(2023, 0o3, 31))
      create(:exchange_rate_currency_rate,
             :average_rate,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2023, 0o3, 1),
             validity_end_date: Date.new(2023, 0o3, 31))
      create(:exchange_rate_currency_rate,
             :average_rate,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2023, 12, 1),
             validity_end_date: Date.new(2023, 12, 31))
      create(:exchange_rate_currency_rate,
             :average_rate,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2023, 12, 1),
             validity_end_date: Date.new(2023, 12, 31))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2023, 12, 1),
             validity_end_date: Date.new(2023, 12, 31))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2023, 12, 1),
             validity_end_date: Date.new(2023, 12, 31))
      create(:exchange_rate_file, type: 'average_csv', period_month: 3, period_year: 2023)
      create(:exchange_rate_file, type: 'average_csv', period_month: 12, period_year: 2023)
    end

    it 'deletes the correct exchange rates', :aggregate_failures do
      expect(ExchangeRateCurrencyRate.count).to eq(6)
      expect(ExchangeRateCurrencyRate.where(rate_type: ExchangeRateCurrencyRate::AVERAGE_RATE_TYPE).count).to eq(4)
      expect(ExchangeRateFile.count).to eq(2)
      remove_old_average_rates

      expect(ExchangeRateCurrencyRate.count).to eq(4)
      expect(ExchangeRateCurrencyRate.where(rate_type: ExchangeRateCurrencyRate::AVERAGE_RATE_TYPE).count).to eq(2)
      expect(ExchangeRateFile.count).to eq(1)
    end
  end

  describe 'Rebuild average rates' do
    subject(:rebuild_average_rates) { Rake::Task['exchange_rates:rebuild_average_rates'].invoke }

    # Set env variables
    let(:avg_period_month) { '12' }
    let(:avg_period_year) { '2023' }

    before do
      ENV['AVG_PERIOD_MONTH'] = avg_period_month
      ENV['AVG_PERIOD_YEAR'] = avg_period_year

      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 2,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2023, 1, 1),
             validity_end_date: Date.new(2023, 1, 31))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 2,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2023, 2, 1),
             validity_end_date: Date.new(2023, 2, 28))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 2,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2023, 3, 1),
             validity_end_date: Date.new(2023, 3, 31))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 2,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2023, 4, 1),
             validity_end_date: Date.new(2023, 4, 30))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 2,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2023, 5, 1),
             validity_end_date: Date.new(2023, 5, 31))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 2,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2023, 6, 1),
             validity_end_date: Date.new(2023, 6, 30))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 2,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2023, 7, 1),
             validity_end_date: Date.new(2023, 7, 31))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 2,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2023, 8, 1),
             validity_end_date: Date.new(2023, 8, 30))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 2,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2023, 9, 1),
             validity_end_date: Date.new(2023, 9, 30))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 2,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2023, 10, 1),
             validity_end_date: Date.new(2023, 10, 31))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 2,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2023, 11, 1),
             validity_end_date: Date.new(2023, 11, 30))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 2,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2023, 12, 1),
             validity_end_date: Date.new(2023, 12, 31))

      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 4,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2023, 1, 1),
             validity_end_date: Date.new(2023, 1, 31))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 4,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2023, 2, 1),
             validity_end_date: Date.new(2023, 2, 28))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 4,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2023, 3, 1),
             validity_end_date: Date.new(2023, 3, 31))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 4,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2023, 4, 1),
             validity_end_date: Date.new(2023, 4, 30))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 4,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2023, 5, 1),
             validity_end_date: Date.new(2023, 5, 31))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 4,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2023, 6, 1),
             validity_end_date: Date.new(2023, 6, 30))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 4,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2023, 7, 1),
             validity_end_date: Date.new(2023, 0o7, 31))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 4,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2023, 8, 1),
             validity_end_date: Date.new(2023, 8, 31))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 4,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2023, 9, 1),
             validity_end_date: Date.new(2023, 9, 30))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 4,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2023, 10, 1),
             validity_end_date: Date.new(2023, 10, 31))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 4,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2023, 11, 1),
             validity_end_date: Date.new(2023, 11, 30))
      create(:exchange_rate_currency_rate,
             :monthly_rate,
             rate: 4,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2023, 12, 1),
             validity_end_date: Date.new(2023, 12, 31))

      create(:exchange_rate_file, type: 'average_csv', period_month: 3, period_year: 2023)
    end

    it 'creates the correct exchange rates', :aggregate_failures do
      expect(ExchangeRateCurrencyRate.count).to eq(24)
      expect(ExchangeRateFile.count).to eq(1)
      rebuild_average_rates

      expect(ExchangeRateCurrencyRate.where(currency_code: eur.currency_code,
                                            validity_end_date: Date.new(2023, 12, 31),
                                            rate_type: 'average').first.rate).to eq(4)
      expect(ExchangeRateCurrencyRate.where(currency_code: usa.currency_code,
                                            validity_end_date: Date.new(2023, 12, 31),
                                            rate_type: 'average').first.rate).to eq(2)
      expect(ExchangeRateCurrencyRate.count).to eq(26)
      expect(ExchangeRateFile.count).to eq(2)
    end
  end
end

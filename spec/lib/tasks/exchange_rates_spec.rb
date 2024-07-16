RSpec.describe ExchangeRates do
  let(:eur) { create(:exchange_rate_country_currency, :eu) }
  let(:usa) { create(:exchange_rate_country_currency, :us) }

  describe 'Remove and rebuild old monthly rates' do
    subject(:rebuild_old_monthly_rates) { Rake::Task['exchange_rates:rebuild_old_monthly_rates'].invoke }

    # Set env variables
    let(:month_start_period) { '8' }
    let(:year_start_period) { '2023' }
    let(:month_end_period) { '10' }
    let(:year_end_period) { '2023' }
    let(:currency_code) { 'EUR' }
    let(:period_start) { Date.new(year_start_period.to_i, month_start_period.to_i) }
    let(:period_end) { Date.new(year_end_period.to_i, month_end_period.to_i) }

    before do
      # different_currency_exchange_rate
      create(:exchange_rate_currency_rate,
             currency_code: usa.currency_code,
             validity_start_date: period_start,
             validity_end_date: period_start.end_of_month)

      create(:exchange_rate_currency_rate,
             currency_code: usa.currency_code,
             validity_start_date: period_end - 1.month,
             validity_end_date: (period_end - 1.month).end_of_month)

      create(:exchange_rate_currency_rate,
             currency_code: usa.currency_code,
             validity_start_date: period_end,
             validity_end_date: period_end.end_of_month)

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

      # within_period_exchange_rate_end_wrong_type
      create(:exchange_rate_currency_rate,
             :average_rate,
             currency_code: eur.currency_code,
             validity_start_date: period_end,
             validity_end_date: period_end.end_of_month)

      # within_period_exchange_rate - SHOULD GET DELETED
      create(:exchange_rate_currency_rate,
             currency_code: eur.currency_code,
             validity_start_date: period_start,
             validity_end_date: period_start.end_of_month)

      create(:exchange_rate_currency_rate,
             currency_code: eur.currency_code,
             validity_start_date: period_end,
             validity_end_date: period_end.end_of_month)

      # =================FILES=============================
      # deleted_exchange_rate_file_beginning
      create(:exchange_rate_file,
             # new file wont be this size to check recreation
             file_size: 99_999_999,
             period_month: month_start_period,
             period_year: year_start_period)

      # deleted_exchange_rate_file_end
      create(:exchange_rate_file,
             file_size: 99_999_999,
             period_month: month_end_period,
             period_year: year_end_period)

      # non_deleted_exchange_rate_file_beginning
      create(:exchange_rate_file,
             file_size: 99_999_999,
             period_month: month_start_period.to_i - 1,
             period_year: year_start_period.to_i)

      # non_deleted_exchange_rate_file_beginning_xml
      create(:exchange_rate_file,
             file_size: 99_999_999,
             type: 'monthly_xml',
             format: 'xml',
             period_month: month_start_period.to_i - 1,
             period_year: year_start_period.to_i)

      # non_deleted_exchange_rate_file_end
      create(:exchange_rate_file,
             file_size: 99_999_999,
             period_month: month_end_period.to_i + 1,
             period_year: year_end_period.to_i)

      # This is more extra test to ensure this file is deleted
      create(:exchange_rate_file,
             period_month: 7, period_year: 2023, type: 'monthly_csv_hmrc')

      ENV['MONTH_START_PERIOD'] = month_start_period
      ENV['YEAR_START_PERIOD'] = year_start_period
      ENV['MONTH_END_PERIOD'] = month_end_period
      ENV['YEAR_END_PERIOD'] = year_end_period
      ENV['CURRENCY_CODE'] = currency_code

      allow(TariffSynchronizer::FileService).to receive(:delete_file)
      allow(TariffSynchronizer::FileService).to receive(:write_file)
      allow(TariffSynchronizer::FileService).to receive(:file_size).and_return(1)
    end

    it 'deletes the correct exchange rates and regenerates the files', :aggregate_failures do
      expect(ExchangeRateCurrencyRate.where(rate_type: ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE).count).to eq(7)
      expect(ExchangeRateCurrencyRate.count).to eq(8)
      expect(ExchangeRateFile.count).to eq(6)

      rebuild_old_monthly_rates

      expect(ExchangeRateCurrencyRate.count).to eq(6)
      expect(ExchangeRateCurrencyRate.where(rate_type: ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE).count).to eq(5)
      expect(ExchangeRateFile.where(period_month: 7, period_year: 2023).count).to eq(2)
      expect(ExchangeRateFile.where(period_month: 8, period_year: 2023).count).to eq(2)
      expect(ExchangeRateFile.where(period_month: 9, period_year: 2023).count).to eq(3)
      expect(ExchangeRateFile.where(period_month: 10, period_year: 2023).count).to eq(3)
      expect(ExchangeRateFile.where(period_month: 11, period_year: 2023).count).to eq(1)

      expect(TariffSynchronizer::FileService)
       .to have_received(:delete_file).exactly(2)
       .times.with(match(/data\/exchange_rates\/2023\/\d{1,2}\/monthly_csv_\d{4}-\d{1,2}.csv/), true)

      expect(TariffSynchronizer::FileService)
       .to have_received(:write_file).exactly(3).times.with(match(/monthly_csv_hmrc_\d{4}-\d{1,2}.csv/), include('Period'))
      expect(TariffSynchronizer::FileService)
       .to have_received(:write_file).exactly(3).times.with(match(/monthly_xml_\d{4}-\d{1,2}.xml/), include('countryName'))
      expect(TariffSynchronizer::FileService)
       .to have_received(:write_file).exactly(3).times.with(match(/monthly_csv_\d{4}-\d{1,2}.csv/), include('Country'))

      # Check the publication date is created correctly
      expect(ExchangeRateFile
        .where(period_month: 8, period_year: 2023)
        .all? { |file| file.publication_date == Date.new(2023, 7, 19) }).to be(true)
      expect(ExchangeRateFile
        .where(period_month: 9, period_year: 2023)
        .all? { |file| file.publication_date == Date.new(2023, 8, 23) }).to be(true)
      expect(ExchangeRateFile
        .where(period_month: 10, period_year: 2023)
        .all? { |file| file.publication_date == Date.new(2023, 9, 20) }).to be(true)
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
             :average_rate,
             currency_code: usa.currency_code,
             validity_start_date: Date.new(2023, 3, 1),
             validity_end_date: Date.new(2023, 3, 31))
      create(:exchange_rate_currency_rate,
             :average_rate,
             currency_code: eur.currency_code,
             validity_start_date: Date.new(2023, 3, 1),
             validity_end_date: Date.new(2023, 3, 31))

      # Average rates to be deleted
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
      create(:exchange_rate_file, type: 'average_csv', period_month: 12, period_year: 2023)

      allow(TariffSynchronizer::FileService).to receive(:delete_file)
      allow(TariffSynchronizer::FileService).to receive(:write_file)
      allow(TariffSynchronizer::FileService).to receive(:file_size).and_return(1)
    end

    it 'creates the correct exchange rates', :aggregate_failures do
      expect(ExchangeRateCurrencyRate.count).to eq(28)
      expect(ExchangeRateCurrencyRate.where(rate_type: ExchangeRateCurrencyRate::AVERAGE_RATE_TYPE).count).to eq(4)
      expect(ExchangeRateFile.count).to eq(2)

      rebuild_average_rates

      expect(ExchangeRateCurrencyRate.where(currency_code: eur.currency_code,
                                            validity_end_date: Date.new(2023, 12, 31),
                                            rate_type: 'average').first.rate).to eq(4)
      expect(ExchangeRateCurrencyRate.where(currency_code: usa.currency_code,
                                            validity_end_date: Date.new(2023, 12, 31),
                                            rate_type: 'average').first.rate).to eq(2)
      expect(ExchangeRateCurrencyRate.count).to eq(28)
      expect(ExchangeRateFile.count).to eq(2)

      expect(TariffSynchronizer::FileService)
       .to have_received(:delete_file)
       .with(match(/data\/exchange_rates\/2023\/\d{1,2}\/average_csv_\d{4}-\d{1,2}.csv/), true)

      expect(TariffSynchronizer::FileService)
       .to have_received(:write_file)
       .with(match(/data\/exchange_rates\/2023\/\d{1,2}\/average_csv_\d{4}-\d{1,2}.csv/),
             include('Country,Unit Of Currency,Currency Code,Sterling value of Currency Unit £,Currency Units per £1'))
    end
  end
end

namespace :exchange_rates do
  desc 'Remove and re-build old monthly rates inclusive of the provided data (does not download from XE)'
  task rebuild_old_monthly_rates: :environment do
    raise ArgumentError, 'Supply an MONTH_START_PERIOD env var' if ENV['MONTH_START_PERIOD'].blank?
    raise ArgumentError, 'Supply an YEAR_START_PERIOD env var' if ENV['YEAR_START_PERIOD'].blank?
    raise ArgumentError, 'Supply an MONTH_END_PERIOD env var' if ENV['MONTH_END_PERIOD'].blank?
    raise ArgumentError, 'Supply an YEAR_END_PERIOD env var' if ENV['YEAR_END_PERIOD'].blank?
    raise ArgumentError, 'Supply an CURRENCY_CODE env var' if ENV['CURRENCY_CODE'].blank?

    from_date = Date.new(ENV['YEAR_START_PERIOD'].to_i, ENV['MONTH_START_PERIOD'].to_i).beginning_of_month
    to_date = Date.new(ENV['YEAR_END_PERIOD'].to_i, ENV['MONTH_END_PERIOD'].to_i).end_of_month

    if ENV['CURRENCY_CODE']
      ExchangeRateCurrencyRate.where(rate_type: ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE,
                                     validity_end_date: from_date.beginning_of_day..to_date.end_of_day,
                                     currency_code: ENV['CURRENCY_CODE']).delete
    end

    months_and_years_between = []

    while from_date <= to_date
      months_and_years_between << [from_date.month, from_date.year]
      from_date = from_date.next_month
    end

    file_types = %w[monthly_csv monthly_xml monthly_csv_hmrc]

    file_types.each do |file_type|
      months_and_years_between.each do |month_and_year|
        month = month_and_year[0]
        year = month_and_year[1]

        # Get DB file object
        file = ExchangeRateFile.where(type: file_type,
                                      period_month: month,
                                      period_year: year).first
        next unless file

        # S3 object location
        s3_file_path = file.object_key

        # Delete DB object
        file.delete

        # Delete file in S3
        TariffSynchronizer::FileService.delete_file(s3_file_path, true)
      end
    end

    months_and_years_between.each do |month_and_year|
      month = month_and_year[0]
      year = month_and_year[1]
      date = Date.new(year, month, 1)

      # publication_date
      last_day_of_previous_month = date - 1
      last_thursday = last_day_of_previous_month.downto(1).find { |d| d.wday == 4 }
      sample_date = last_thursday - 8

      # Note we dont download from XE new rates
      ExchangeRates::MonthlyExchangeRatesService.new(date, sample_date, download: false).call
    end

    # We dont want to have the HMRC CSV pre Aug 2023 so this clears out those files
    date_range = (Date.new(2000, 1, 1)..Date.new(2023, 8, 31)).select { |d| d.day == 1 }
    date_array = date_range.map { |date| [date.month, date.year] }

    date_array.each do |month_and_year|
      month = month_and_year[0]
      year = month_and_year[1]

      ExchangeRateFile.where(type: 'monthly_csv_hmrc',
                             period_month: month,
                             period_year: year).delete
    end
  end

  # This only accepts one period to delete the file and all the avg rates in that month
  desc 'Remove and rebuild average rates'
  task rebuild_average_rates: :environment do
    raise 'Supply an AVG_PERIOD_MONTH env var' if ENV['AVG_PERIOD_MONTH'].blank?
    raise 'Supply an AVG_PERIOD_YEAR env var' if ENV['AVG_PERIOD_YEAR'].blank?
    raise 'Invalid' unless ExchangeRates::CreateAverageExchangeRatesService::VALID_MONTHS.include?(ENV['AVG_PERIOD_MONTH'].to_i)

    validity_end_date = Date.new(ENV['AVG_PERIOD_YEAR'].to_i, ENV['AVG_PERIOD_MONTH'].to_i, 31)

    ExchangeRateCurrencyRate.where(rate_type: ExchangeRateCurrencyRate::AVERAGE_RATE_TYPE, validity_end_date:).delete
    file = ExchangeRateFile.where(type: 'average_csv', period_month: ENV['AVG_PERIOD_MONTH'], period_year: ENV['AVG_PERIOD_YEAR']).first

    if file
      # S3 object location
      s3_file_path = file.object_key
      # Delete DB object
      file.delete
      # Delete file in S3
      TariffSynchronizer::FileService.delete_file(s3_file_path, true)
    end

    # The average rates are only ever run on the 31st of March or December
    date = validity_end_date.iso8601

    ExchangeRates::CreateAverageExchangeRatesService.call(force_run: false, selected_date: date)
  end
end

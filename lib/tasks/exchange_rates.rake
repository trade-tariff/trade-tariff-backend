namespace :exchange_rates do
  desc 'Remove old monthly rates inclusive of the provided date'
  task remove_old_monthly_rates: :environment do
    raise ArgumentError, 'Supply an MONTH_START_PERIOD env var' if ENV['MONTH_START_PERIOD'].blank?
    raise ArgumentError, 'Supply an YEAR_START_PERIOD env var' if ENV['YEAR_START_PERIOD'].blank?
    raise ArgumentError, 'Supply an MONTH_END_PERIOD env var' if ENV['MONTH_END_PERIOD'].blank?
    raise ArgumentError, 'Supply an YEAR_END_PERIOD env var' if ENV['YEAR_END_PERIOD'].blank?
    raise ArgumentError, 'Supply an CURRENCY_CODE env var' if ENV['CURRENCY_CODE'].blank?

    from_date = Date.new(ENV['YEAR_START_PERIOD'].to_i, ENV['MONTH_START_PERIOD'].to_i).beginning_of_month
    to_date = Date.new(ENV['YEAR_END_PERIOD'].to_i, ENV['MONTH_END_PERIOD'].to_i).end_of_month

    ExchangeRateCurrencyRate.where(rate_type: ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE,
                                   validity_end_date: from_date.beginning_of_day..to_date.end_of_day,
                                   currency_code: ENV['CURRENCY_CODE']).delete

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

        ExchangeRateFile.where(type: file_type,
                               period_month: month,
                               period_year: year).delete
      end
    end
  end

  desc 'Rebuild monthly rates'
  task rebuild_monthly_rates: :environment do
    raise ArgumentError, 'Supply an MONTH_START_PERIOD env var' if ENV['MONTH_START_PERIOD'].blank?
    raise ArgumentError, 'Supply an YEAR_START_PERIOD env var' if ENV['YEAR_START_PERIOD'].blank?
    raise ArgumentError, 'Supply an MONTH_END_PERIOD env var' if ENV['MONTH_END_PERIOD'].blank?
    raise ArgumentError, 'Supply an YEAR_END_PERIOD env var' if ENV['YEAR_END_PERIOD'].blank?

    from_date = Date.new(ENV['YEAR_START_PERIOD'].to_i, ENV['MONTH_START_PERIOD'].to_i).beginning_of_month
    to_date = Date.new(ENV['YEAR_END_PERIOD'].to_i, ENV['MONTH_END_PERIOD'].to_i).end_of_month

    months_and_years_between = []

    while from_date <= to_date
      months_and_years_between << [from_date.month, from_date.year]
      from_date = from_date.next_month
    end

    months_and_years_between.each do |month_and_year|
      month = month_and_year[0]
      year = month_and_year[1]

      sample_date = find_sample_date(year, month)
      date = Date.new(year, month, 1)

      ExchangeRates::MonthlyExchangeRatesService.new(date, sample_date, download: false).call
    end
  end

  # This only accepts one period to delete the file and all the avg rates in that month
  desc 'Remove average rates'
  task remove_old_average_rates: :environment do
    raise 'Supply an AVG_PERIOD_MONTH env var' if ENV['AVG_PERIOD_MONTH'].blank?
    raise 'Supply an AVG_PERIOD_YEAR env var' if ENV['AVG_PERIOD_YEAR'].blank?

    validity_end_date = Date.new(ENV['AVG_PERIOD_YEAR'].to_i, ENV['AVG_PERIOD_MONTH'].to_i, 31)

    ExchangeRateCurrencyRate.where(rate_type: ExchangeRateCurrencyRate::AVERAGE_RATE_TYPE, validity_end_date:).delete
    ExchangeRateFile.where(type: 'average_csv', period_month: ENV['AVG_PERIOD_MONTH'], period_year: ENV['AVG_PERIOD_YEAR']).delete
  end

  desc 'Rebuild average rates'
  task rebuild_average_rates: :environment do
    raise 'Supply an AVG_PERIOD_MONTH env var' if ENV['AVG_PERIOD_MONTH'].blank?
    raise 'Supply an AVG_PERIOD_YEAR env var' if ENV['AVG_PERIOD_YEAR'].blank?
    raise 'Invalid' if ExchangeRates::CreateAverageExchangeRatesService::VALID_MONTHS.include?(ENV['AVG_PERIOD_MONTH'])

    # The average rates are only ever run on the 31st of March or December
    date = Date.new(ENV['AVG_PERIOD_YEAR'].to_i, ENV['AVG_PERIOD_MONTH'].to_i, 31).iso8601

    ExchangeRates::CreateAverageExchangeRatesService.call(force_run: false, selected_date: date)
  end
end

def find_sample_date(year, month)
  # To get the sample date we need to supply the seleceted month and year
  # then go back to the last thursday of the month before and
  # minus 1 day when the task would normally be run.

  last_day_of_previous_month = Date.new(year, month, 1) - 1

  result = nil
  (0..6).reverse_each do |day_offset|
    day = last_day_of_previous_month - day_offset
    if day.wday == 4
      result = day
      break
    end
  end

  result - 1
end

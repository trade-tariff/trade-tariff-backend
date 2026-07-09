module ExchangeRatesRakeTasks
  FILE_TYPES = %w[monthly_csv monthly_xml monthly_csv_hmrc].freeze

module_function

  def rebuild_old_monthly_rates
    require_monthly_env!
    from_date, to_date = monthly_date_range
    months_and_years = months_and_years_between(from_date, to_date)

    delete_monthly_rates(from_date, to_date)
    delete_monthly_files(months_and_years)
    rebuild_monthly_files(months_and_years)
    prune_old_hmrc_monthly_files
  end

  def rebuild_average_rates
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

  def require_monthly_env!
    raise ArgumentError, 'Supply an MONTH_START_PERIOD env var' if ENV['MONTH_START_PERIOD'].blank?
    raise ArgumentError, 'Supply an YEAR_START_PERIOD env var' if ENV['YEAR_START_PERIOD'].blank?
    raise ArgumentError, 'Supply an MONTH_END_PERIOD env var' if ENV['MONTH_END_PERIOD'].blank?
    raise ArgumentError, 'Supply an YEAR_END_PERIOD env var' if ENV['YEAR_END_PERIOD'].blank?
    raise ArgumentError, 'Supply an CURRENCY_CODE env var' if ENV['CURRENCY_CODE'].blank?
  end

  def monthly_date_range
    from_date = Date.new(ENV['YEAR_START_PERIOD'].to_i, ENV['MONTH_START_PERIOD'].to_i).beginning_of_month
    to_date = Date.new(ENV['YEAR_END_PERIOD'].to_i, ENV['MONTH_END_PERIOD'].to_i).end_of_month

    [from_date, to_date]
  end

  def months_and_years_between(from_date, to_date)
    [].tap do |months_and_years|
      while from_date <= to_date
        months_and_years << [from_date.month, from_date.year]
        from_date = from_date.next_month
      end
    end
  end

  def delete_monthly_rates(from_date, to_date)
    ExchangeRateCurrencyRate.where(rate_type: ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE,
                                   validity_end_date: from_date.beginning_of_day..to_date.end_of_day,
                                   currency_code: ENV['CURRENCY_CODE']).delete
  end

  def delete_monthly_files(months_and_years)
    Sequel::Model.db.transaction do
      FILE_TYPES.each do |file_type|
        months_and_years.each do |month, year|
          delete_exchange_rate_file(file_type, month, year)
        end
      end
    end
  end

  def delete_exchange_rate_file(file_type, month, year)
    file = ExchangeRateFile.where(type: file_type, period_month: month, period_year: year).first
    return unless file

    s3_file_path = file.object_key
    file.delete
    TariffSynchronizer::FileService.delete_file(s3_file_path, true)
  end

  def rebuild_monthly_files(months_and_years)
    months_and_years.each do |month, year|
      date = Date.new(year, month, 1)

      ExchangeRates::MonthlyExchangeRatesService.new(date, sample_date_for(date), download: false).call
    end
  end

  def sample_date_for(date)
    last_day_of_previous_month = date - 1
    last_thursday_of_month_before = last_day_of_previous_month.downto(1).find { |d| d.wday == 4 }

    last_thursday_of_month_before - 8
  end

  def prune_old_hmrc_monthly_files
    (Date.new(2000, 1, 1)..Date.new(2023, 8, 31)).select { |date| date.day == 1 }.each do |date|
      ExchangeRateFile.where(type: 'monthly_csv_hmrc', period_month: date.month, period_year: date.year).delete
    end
  end
end

namespace :exchange_rates do
  desc 'Remove and re-build old monthly rates inclusive of the provided data (does not download from XE)'
  task rebuild_old_monthly_rates: :environment do
    ExchangeRatesRakeTasks.rebuild_old_monthly_rates
  end

  # This only accepts one period to delete the file and all the avg rates in that month
  desc 'Remove and rebuild average rates'
  task rebuild_average_rates: :environment do
    ExchangeRatesRakeTasks.rebuild_average_rates
  end
end

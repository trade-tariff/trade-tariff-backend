# DELETE once this has been run
module ExchangeRates
  class CreateOldFilesService
    MONTH_INDEX = 0
    YEAR_INDEX = 1

    def self.call
      new.call
    end

    def call
      old_file_dates.each do |date_hash|
        month_name = date_hash[:edition_date].split(' ')[MONTH_INDEX]
        month = Date::MONTHNAMES.index(month_name)
        year = date_hash[:edition_date].split(' ')[YEAR_INDEX]

        data_result = ::ExchangeRateCurrencyRate.for_month(month, year)

        created_date = date_hash[:updated_date]

        upload_data(data_result,
                    :csv,
                    ExchangeRates::CreateCsvService,
                    created_date,
                    month,
                    year)
        upload_data(data_result,
                    :xml,
                    ExchangeRates::CreateXmlService,
                    created_date,
                    month,
                    year)
      end
    end

  private

    def upload_data(data_result, format, service_class, created_date, month, year)
      data_string = service_class.call(data_result)
      file_path = "data/exchange_rates/monthly_#{format}_#{year}-#{month}.#{format}"
      TariffSynchronizer::FileService.write_file(file_path, data_string)

      file_size = TariffSynchronizer::FileService.file_size(file_path)
      ExchangeRateFile.create(period_year: year,
                              period_month: month,
                              format:,
                              file_size:,
                              publication_date: created_date.to_time)

      info_message = "exchange_rates.monthly_#{format}-#{file_path}-size: #{file_size}"

      Rails.logger.info(info_message)
    end

    def old_file_dates
      [
        {
          "edition_date": 'August 2023',
          "updated_date": '2023-07-20',
        },
        {
          "edition_date": 'July 2023',
          "updated_date": '2023-06-22',
        },
        {
          "edition_date": 'June 2023',
          "updated_date": '2023-05-18',
        },
        {
          "edition_date": 'May 2023',
          "updated_date": '2023-04-20',
        },
        {
          "edition_date": 'April 2023',
          "updated_date": '2023-03-23',
        },
        {
          "edition_date": 'March 2023',
          "updated_date": '2023-02-16',
        },
        {
          "edition_date": 'February 2023',
          "updated_date": '2023-01-19',
        },
        {
          "edition_date": 'January 2023',
          "updated_date": '2022-12-22',
        },
        {
          "edition_date": 'December 2022',
          "updated_date": '2022-11-17',
        },
        {
          "edition_date": 'November 2022',
          "updated_date": '2022-10-20',
        },
        {
          "edition_date": 'October 2022',
          "updated_date": '2022-09-22',
        },
        {
          "edition_date": 'September 2022',
          "updated_date": '2022-08-18',
        },
        {
          "edition_date": 'August 2022',
          "updated_date": '2022-07-21',
        },
        {
          "edition_date": 'July 2022',
          "updated_date": '2022-06-23',
        },
        {
          "edition_date": 'June 2022',
          "updated_date": '2022-05-19',
        },
        {
          "edition_date": 'May 2022',
          "updated_date": '2022-04-21',
        },
        {
          "edition_date": 'April 2022',
          "updated_date": '2022-03-24',
        },
        {
          "edition_date": 'March 2022',
          "updated_date": '2022-02-17',
        },
        {
          "edition_date": 'February 2022',
          "updated_date": '2022-01-20',
        },
        {
          "edition_date": 'January 2022',
          "updated_date": '2021-12-23',
        },
        {
          "edition_date": 'December 2021',
          "updated_date": '2021-11-18',
        },
        {
          "edition_date": 'November 2021',
          "updated_date": '2021-10-21',
        },
        {
          "edition_date": 'October 2021',
          "updated_date": '2021-09-23',
        },
        {
          "edition_date": 'September 2021',
          "updated_date": '2021-08-19',
        },
        {
          "edition_date": 'August 2021',
          "updated_date": '2021-07-22',
        },
        {
          "edition_date": 'July 2021',
          "updated_date": '2021-06-17',
        },
        {
          "edition_date": 'June 2021',
          "updated_date": '2021-05-20',
        },
        {
          "edition_date": 'May 2021',
          "updated_date": '2021-04-22',
        },
        {
          "edition_date": 'April 2021',
          "updated_date": '2021-03-18',
        },
        {
          "edition_date": 'March 2021',
          "updated_date": '2021-02-18',
        },
        {
          "edition_date": 'February 2021',
          "updated_date": '2021-01-21',
        },
        {
          "edition_date": 'January 2021',
          "updated_date": '2020-12-24',
        },
      ]
    end
  end
end

# Import TARIC or CDS file manually. Usually for initial seed files.
namespace :importer do
  namespace :rates do
    desc 'Import Average Exchange Rates'

    task import_agv_ex_rates: %i[environment] do
      end_dates = [
        '31 March 2020',
        '31 December 2020',
        '31 March 2021',
        '31 December 2021',
        '31 March 2022',
        '31 December 2022',
        '31 March 2023',
      ]

      import_avg_exchange_rate_csv(end_dates[6])
    end

    # rubocop:disable Rake/MethodDefinitionInTask
    def import_avg_exchange_rate_csv(end_date)
      # Example of valid filename: "Average for the year to 31 March 2020.csv"
      filename = "./lib/tasks/exchange_rates_averages/Average for the year to #{end_date}.csv"
      data = CSV.read(filename, headers: true)

      validity_end_date = Date.parse(end_date)
      validity_start_date = validity_end_date - 1.year

      invalid_rows = []
      invalid_records = []
      invalid_countries = []
      new_records_count = 0

      puts 'Importing Exchange rates ...'

      data.each do |row|
        if invalid?(row)
          invalid_rows << row

          puts 'Invalid row'
          next
        end

        country_name = row[0].strip # Country
        country = ExchangeRateCountry.where(country: country_name).first

        if country.nil?
          puts "Invalid name for country: #{country_name}"
          invalid_countries << country_name

          next
        end

        currency_code = country.currency_code

        new_rate = ExchangeRateCurrencyRate.new(currency_code:,
                                                validity_start_date:,
                                                validity_end_date:,
                                                rate_type: 'average',
                                                rate: row['Currency Units per pound'].to_f)
        if new_rate.valid?
          new_rate.save
          new_records_count += 1
        else
          invalid_records << new_rate

          puts 'Invalid record'
          next
        end
      end

      puts '- - - Outcome - - -'
      puts "New exchage rates imported: #{new_records_count}"
      puts "Invalid CSV rows: #{invalid_rows.count}"
      puts "Invalid records: #{invalid_records.count}"

      puts "Invalid countries: #{invalid_countries.join(', ')}"
    end

    def invalid?(row)
      row.to_hash.values.any?(&:empty?)
    end
    # rubocop:enable Rake/MethodDefinitionInTask
  end
end

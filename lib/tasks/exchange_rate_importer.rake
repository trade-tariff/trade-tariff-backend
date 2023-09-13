# Import TARIC or CDS file manually. Usually for initial seed files.
namespace :importer do
  namespace :rates do
    desc 'Import Average Exchange Rates'

    task import_agv_ex_rates: %i[environment] do
      average_type = 'average'

      url = 'https://assets.publishing.service.gov.uk/government/uploads/system/uploads/attachment_data/file/1154375/Average_for_the_year_to_31_March_2023.csv'

      client = Faraday.new
      response = client.get(url)

      csv = csv_without_title(response.body)

      data = CSV.parse(csv, headers: true)

      validity_end_date = Date.new(2023, 3, 31)
      validity_start_date = validity_end_date - 1.year # TODO: assuming that average period is one year - To be confirmed!

      invalid_rows = []
      invalid_records = []
      new_records_count = 0

      puts 'Importing Exchange rates ...'

      data.each do |row|
        if invalid?(row)
          invalid_rows << row

          puts 'Invalid row'
          next
        end

        currency_unit_per_pound = row[4].to_f # Currency Units per £1

        new_rate = ExchangeRateCurrencyRate.new(currency_code: row['Currency Code'],
                                                validity_start_date:,
                                                validity_end_date:,
                                                rate_type: average_type,
                                                rate: currency_unit_per_pound)

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
    end

    # rubocop:disable Rake/MethodDefinitionInTask
    def invalid?(row)
      row.to_hash.values.any?(&:empty?)
    end

    def csv_without_title(text)
      start_valid_data = 0

      if text.include?('Average for the year')
        start_valid_data = text.index("\r\n") + 2 # skip the first row with the Title
      end

      text[start_valid_data..]
    end
    # rubocop:enable Rake/MethodDefinitionInTask
  end
end

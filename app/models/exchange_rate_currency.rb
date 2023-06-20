class ExchangeRateCurrency < Sequel::Model
  CURRENCY_FILE = 'data/exchange_rates/currency-master-data-set.xlsx'.freeze

  class << self
    def populate
      unrestrict_primary_key

      worksheet.each_row_streaming(offset: 1) do |row|
        currency_code = row[0]
        currency_description = row[1]
        spot_rate_required = row[2]&.value == true

        ExchangeRateCurrency.create(currency_code:, currency_description:, spot_rate_required:)
      end

      restrict_primary_key
    end

    private

    def workbook
      Roo::Spreadsheet.open(CURRENCY_FILE)
    end

    def worksheet
      workbook.sheet(0)
    end
  end
end

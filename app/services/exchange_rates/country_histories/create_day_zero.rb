module ExchangeRates
  module CountryHistories
    class CreateDayZero
      attr_reader :csv_data

      def self.call(csv_path)
        new(csv_path).call
      end

      def initialize(csv_path)
        @csv_data = CSV.read(csv_path, headers: true)
      end

      def call
        return argument_error unless validate_headings

        import_country_histories

      rescue Sequel::NotNullConstraintViolation => error
        Rails.logger.error(error.message)
      end

      def import_country_histories
        csv_data.each do |row|
          create_country_history(row.to_hash)
        end
      end

      def create_country_history(row)
        ExchangeRateCountryHistory.create(
          country: row['country'],
          country_code: row['country_code'],
          currency_code: row['currency_code'],
          currency_description: row['currency_description'],
          start_date: Time.zone.today.beginning_of_day,
          end_date: nil,
        )
      end

      private

      def validate_headings
        csv_data.headers == %w[country country_code currency_code currency_description]
      end

      def argument_error
        error_message = 'Argument error, invalid headings day zero'

        Rails.logger.error(error_message)

        raise ArgumentError, error_message
      end
    end
  end
end

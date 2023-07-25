module ExchangeRates
  class ExchangeRateFile
    attr_accessor :file_path, :file_size, :format, :year, :month

    def id
      "#{year}-#{month}-#{format}_file"
    end

    attr_reader :format, :file_path

    class << self
      def wrap(files)
        files.map do |file|
          build(file)
        end
      end

      def build(exchange_rate_file)
        exchange_rate_file = new
        exchange_rate_file.file_path = file_path
        exchange_rate_file.file_size = file_size
        exchange_rate_file.format = format
        exchange_rate_file
      end
    end
  end
end

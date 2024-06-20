module Api
  module V2
    module ExchangeRates
      class FilesController < ApiController
        def show
          validate_params!

          filename = ExchangeRateFile.filename_for_download(period_type, format, year, month)

          send_data(
            file_data,
            type: type_header,
            disposition: "attachment; filename=#{filename}",
          )
        end

        private

        def period_type
          regexp = Regexp.new("^(#{ExchangeRateFile::APPLICABLE_TYPES.join('|')})_")
          match_data = param_id.match(regexp)

          match_data[1] if match_data
        end

        def month
          @month ||= param_id.split('-').last
        end

        def year
          @year ||= param_id.split('-').first.split('_').last
        end

        def param_id
          params[:id].to_s
        end

        def format
          request.format.symbol
        end

        def type_header
          header = request.format.symbol == :csv ? 'text/csv' : 'application/xml'
          header.concat('; charset=utf-8; header=present')
        end

        def file_data
          TariffSynchronizer::FileService
            .get(file.object_key)
            .read
        end

        def file
          @file ||= ExchangeRateFile.where(
            type: period_type,
            period_year: year,
            period_month: month,
            format: format.to_s,
          ).take
        end

        def validate_params!
          if period_type.nil?
            raise ArgumentError,
                  "Invalid file type. Expected one of: #{ExchangeRateFile::APPLICABLE_TYPES.join(', ')}"
          end
        end
      end
    end
  end
end

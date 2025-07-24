module Api
  module V2
    module ExchangeRates
      class FilesController < ApiController
        def show
          filename = ExchangeRateFile.filename_for_download(type, format, year, month)

          send_data(
            file_data,
            type: type_header,
            disposition: "attachment; filename=#{filename}",
          )
        end

        private

        def type
          match_data = id.match(/^(monthly_csv_hmrc|monthly_csv|monthly_xml|average_csv|spot_csv)_/)
          match_data[1] if match_data
        end

        def month
          @month ||= params[:id].split('-').last.sub('0', '')
        end

        def year
          @year ||= params[:id].split('-').first.split('_').last
        end

        def id
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
            type:,
            period_year: year,
            period_month: month,
            format: format.to_s,
          ).take
        end
      end
    end
  end
end

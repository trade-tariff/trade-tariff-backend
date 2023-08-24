module Api
  module V2
    module ExchangeRates
      class FilesController < ApiController
        def show
          filename = ExchangeRateFile.filename_for(type, format, year, month)

          send_data(
            file_data,
            type: type_header,
            disposition: "attachment; filename=#{filename}",
          )
        end

        private

        def type
          id.split('_').first(2).join('_')
        end

        def month
          @month ||= params[:id].split('-').last
        end

        def year
          @year ||= params[:id].split('-').first.split('_').last
        end

        def id
          params[:id].to_s
        end

        def filename_for(type, format)
          "#{type}_#{year}-#{month}.#{format}"
        end

        def format
          request.format.symbol
        end

        def type_header
          header = request.format.symbol == :csv ? 'text/csv' : 'application/xml'
          header.concat('; charset=utf-8; header=present')
        end

        def file_data
          object_key = ExchangeRateFile.filepath_for(type, format, year, month)

          TariffSynchronizer::FileService
            .get(object_key)
            .read
        end
      end
    end
  end
end

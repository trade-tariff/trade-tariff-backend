module Api
  module V2
    module ExchangeRates
      class FilesController < ApiController
        def show
          filename = ExchangeRateFile.filename_for_download(params[:type],
                                                            format,
                                                            params[:year],
                                                            params[:month])

          send_data(
            file_data,
            type: type_header,
            disposition: "attachment; filename=#{filename}",
          )
        end

        private

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
            type: params[:type],
            period_year: params[:year],
            period_month: params[:month],
            format: format.to_s,
          ).take
        end
      end
    end
  end
end

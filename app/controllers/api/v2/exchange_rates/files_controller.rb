module Api
  module V2
    module ExchangeRates
      class FilesController < ApiController
        def index
          respond_to do |format|
            format.csv do
              filename = ExchangeRateFile.filename_for('monthly_csv', 'csv', year, month)

              send_data(
                serialized_csv,
                type: 'text/csv; charset=utf-8; header=present',
                disposition: "attachment; filename=#{filename}",
              )
            end
            format.xml do
              filename = ExchangeRateFile.filename_for('monthly_xml', 'xml', year, month)

              send_data(
                serialized_xml,
                type: 'application/xml; charset=utf-8; header=present',
                disposition: "attachment; filename=#{filename}",
              )
            end
          end
        end

        private

        def month
          @month ||= params[:month].to_i
        end

        def year
          @year ||= params[:year].to_i
        end

        def filename_for(type, format)
          "#{type}_#{year}-#{month}.#{format}"
        end

        def serialized_csv
          object_key = ExchangeRateFile.filepath_for('monthly_csv', 'csv', year, month)

          TariffSynchronizer::FileService
            .get(object_key)
            .read
        end

        def serialized_xml
          object_key = ExchangeRateFile.filepath_for('monthly_xml', 'xml', year, month)

          TariffSynchronizer::FileService
            .get(object_key)
            .read
        end
      end
    end
  end
end

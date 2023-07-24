module Api
  module V2
    module ExchangeRates
      class FilesController < ApiController
        def index
          respond_to do |format|
            format.csv do
              send_data(
                serialized_csv,
                type: 'text/csv; charset=utf-8; header=present',
                disposition: "attachment; filename=#{TradeTariffBackend.service}-monthly_csv_#{year}-#{month}.csv",
              )
            end
            format.xml do
              send_data(
                serialized_xml,
                type: 'application/xml; charset=utf-8; header=present',
                disposition: "attachment; filename=#{TradeTariffBackend.service}-monthly_xml_#{year}-#{month}.xml",
              )
            end
          end
        end

        private

        def month
          params[:month].to_i
        end

        def year
          params[:year].to_i
        end

        def serialized_csv
          TariffSynchronizer::FileService
            .get("data/exchange_rates/monthly_csv_#{year}-#{month}.csv")
            .read
        end

        def serialized_xml
          TariffSynchronizer::FileService
            .get("data/exchange_rates/monthly_xml_#{year}-#{month}.xml")
            .read
        end
      end
    end
  end
end

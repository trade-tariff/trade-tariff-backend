module Api
  module V2
    module ExchangeRates
      class ExchangeRateFileSerializer
        include JSONAPI::Serializer

        set_type :exchange_rate_file

        attributes :file_path,
                   :file_size,
                   :format,
                   :publication_date
      end
    end
  end
end

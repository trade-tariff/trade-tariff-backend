module Api
  module V2
    module Shared
      class ImportTradeSummarySerializer
        include JSONAPI::Serializer

        set_type :import_trade_summary

        attributes :basic_third_country_duty,
                   :preferential_tariff_duty,
                   :preferential_quota_duty
      end
    end
  end
end

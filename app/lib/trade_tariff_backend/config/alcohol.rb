module TradeTariffBackend
  module Config
    module Alcohol
      def alcohol_coercian_starts_from
        ENV.fetch('ALCOHOL_COERCIAN_STARTS_FROM', '2022-01-01')
      end

      def excise_alcohol_coercian_starts_from
        @excise_alcohol_coercian_starts_from ||= Date.parse(alcohol_coercian_starts_from)
      end
    end
  end
end

module TradeTariffBackend
  module Config
    module GoodsNomenclature
      def goods_nomenclature_label_page_size
        ENV.fetch('GOODS_NOMENCLATURE_LABEL_PAGE_SIZE', '10').to_i
      end
    end
  end
end

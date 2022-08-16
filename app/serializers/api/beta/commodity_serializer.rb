module Api
  module Beta
    class CommoditySerializer < GoodsNomenclatureSerializer
      set_type :commodity

      attributes :chapter_description,
                 :chapter_id,
                 :heading_description,
                 :heading_id,
                 :validity_start_date,
                 :validity_end_date

      def validity_start_date
        super&.iso8601
      end

      def validity_end_date
        super&.iso8601
      end
    end
  end
end

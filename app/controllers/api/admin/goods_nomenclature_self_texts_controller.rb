module Api
  module Admin
    class GoodsNomenclatureSelfTextsController < AdminController
      include GeneratedContentListing

      private

      def model_class
        GoodsNomenclatureSelfText
      end

      def serializer_class
        GoodsNomenclatures::GoodsNomenclatureSelfTextSerializer
      end

      def listing_table
        Sequel[:goods_nomenclature_self_texts]
      end
    end
  end
end

module Api
  module Admin
    class GoodsNomenclatureAutocompleteController < AdminController
      def index
        render json: Api::Admin::GoodsNomenclatureAutocompleteSerializer.new(results).serializable_hash
      end

      private

      def results
        @results ||= SearchSuggestion
          .goods_nomenclature_autocomplete_with_filters(params[:q], autocomplete_filters)
          .all
          .select { |suggestion| suggestion.goods_nomenclature.present? }
      end

      def autocomplete_filters
        goods_nomenclature_class = params.dig(:filter, :goods_nomenclature_class) ||
          params.dig(:filter, 'goods_nomenclature_class')

        { goods_nomenclature_class: }
      end
    end
  end
end

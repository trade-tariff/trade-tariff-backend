module Api
  module V2
    module GreenLanes
      class GoodsNomenclaturesController < BaseController
        def show
          gn = ::GreenLanes::FetchGoodsNomenclatureService.new(params[:id]).call
          presented_gn = GoodsNomenclaturePresenter.new(gn, filter_params[:geographical_area_id])

          render json: serializer_for(presented_gn).serializable_hash
        end

      private

        def filter_params
          params.fetch(:filter, {})
                .permit(:geographical_area_id)
        end

        def serializer_for(goods_nomenclature)
          GreenLanes::GoodsNomenclatureSerializer.new(goods_nomenclature, include: %w[
            applicable_category_assessments
            applicable_category_assessments.exemptions
            applicable_category_assessments.geographical_area
            applicable_category_assessments.excluded_geographical_areas
            applicable_category_assessments.measures
            applicable_category_assessments.measures.measure_types
            applicable_category_assessments.measures.footnotes
            ancestors
            ancestors.measures
            ancestors.measures.measure_types
            ancestors.measures.footnotes
            measures
            measures.measure_types
            measures.footnotes
          ])
        end
      end
    end
  end
end

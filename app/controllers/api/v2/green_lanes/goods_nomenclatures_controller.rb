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
          GreenLanes::GoodsNomenclatureSerializer.new \
            goods_nomenclature,
            params: { with_measures: true },
            include: %w[
              applicable_category_assessments
              applicable_category_assessments.regulation
              applicable_category_assessments.measure_type
              applicable_category_assessments.geographical_area
              applicable_category_assessments.excluded_geographical_areas
              applicable_category_assessments.exemptions
              applicable_category_assessments.measures
              applicable_category_assessments.measures.footnotes
              applicable_category_assessments.theme
              descendant_category_assessments
              descendant_category_assessments.regulation
              descendant_category_assessments.measure_type
              descendant_category_assessments.exemptions
              descendant_category_assessments.geographical_area
              descendant_category_assessments.excluded_geographical_areas
              descendant_category_assessments.measures
              descendant_category_assessments.measures.footnotes
              descendant_category_assessments.theme
              licences
              ancestors
              ancestors.licences
              descendants
              descendants.licences
            ]
        end
      end
    end
  end
end

module Api
  module V2
    module GreenLanes
      class GoodsNomenclaturesController < BaseController
        def show
          gn = ::GreenLanes::FetchGoodsNomenclatureService.new(params[:id]).call
          applicable_assessments_and_measures =
            ::GreenLanes::FindCategoryAssessmentsService.call(
              goods_nomenclature: gn,
              geographical_area_id: filter_params[:geographical_area_id],
            )

          presented_gn = GoodsNomenclaturePresenter.new(gn, applicable_assessments_and_measures)
          serializer = Api::V2::GreenLanes::GoodsNomenclatureSerializer.new(
            presented_gn, include: %w[
              applicable_category_assessments
              applicable_category_assessments.exemptions
              applicable_category_assessments.geographical_area
              applicable_category_assessments.excluded_geographical_areas
              applicable_category_assessments.measures
              applicable_category_assessments.measures.footnotes
            ]
          )

          render json: serializer.serializable_hash
        end

        def filter_params
          params.fetch(:filter, {})
                .permit(:geographical_area_id)
        end
      end
    end
  end
end

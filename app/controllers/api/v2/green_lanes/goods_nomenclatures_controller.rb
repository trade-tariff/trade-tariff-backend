module Api
  module V2
    module GreenLanes
      class GoodsNomenclaturesController < BaseController
        def show
          # Excluding the origin param continues to supply the same categorisation information as previously
          # Including an origin param
          # - includes categorisations which match the origin,
          #   or which do not have a geographical area restriction = geographical_area: nil or
          # - param excludes categorisations for geographical areas not matching the origin param
          # 1. pass in the origin param
          # 2. filter the geographical area code using the origin param

          gn = ::GreenLanes::FetchGoodsNomenclatureService.new(params[:id]).call
          applicable_category_assessments = ::GreenLanes::FindCategoryAssessmentsService.new.call(gn)
          presented_gn = GoodsNomenclaturePresenter.new(gn, applicable_category_assessments)
          serializer = Api::V2::GreenLanes::GoodsNomenclatureSerializer.new(presented_gn, include: %w[applicable_measures applicable_category_assessments])

          render json: serializer.serializable_hash
        end
      end
    end
  end
end

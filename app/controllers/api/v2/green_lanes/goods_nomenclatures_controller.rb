module Api
  module V2
    module GreenLanes
      class GoodsNomenclaturesController < BaseController
        def show
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

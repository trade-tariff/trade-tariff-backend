module Api
  module V2
    module GreenLanes
      class GoodsNomenclaturesController < BaseController
        def show
          gn = ::GreenLanes::FetchGoodsNomenclatureService.new(params[:id]).call
          applicable_category_assessments = ::GreenLanes::FindCategorisationsService.call(
            goods_nomenclature: gn,
            origin: filter_params[:origin],
          )

          presented_gn = GoodsNomenclaturePresenter.new(gn, applicable_category_assessments)
          serializer = Api::V2::GreenLanes::GoodsNomenclatureSerializer.new(
            presented_gn, include: %w[applicable_measures applicable_category_assessments]
          )

          render json: serializer.serializable_hash
        end

        def filter_params
          params.fetch(:filter, {})
                .permit(:origin)
        end
      end
    end
  end
end

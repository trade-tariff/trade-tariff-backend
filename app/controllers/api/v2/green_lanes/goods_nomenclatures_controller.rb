module Api
  module V2
    module GreenLanes
      class GoodsNomenclaturesController < BaseController
        def show
          gn = ::GreenLanes::FetchGoodsNomenclatureService.new(params[:id]).call
          presented_gn = SubheadingPresenter.new(gn)
          serializer = Api::V2::GreenLanes::SubheadingSerializer.new(presented_gn, include: %w[applicable_measures])

          render json: serializer.serializable_hash
        end
      end
    end
  end
end

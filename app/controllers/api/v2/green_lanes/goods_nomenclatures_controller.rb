module Api
  module V2
    module GreenLanes
      class GoodsNomenclaturesController < BaseController
        def show
          gn = ::GreenLanes::FetchGoodsNomenclatureService.new(params[:id]).call
          possible_categorisations = ::GreenLanes::FindCategorisationsService.new.call(gn)
          presented_gn = GoodsNomenclaturePresenter.new(gn, possible_categorisations)
          serializer = Api::V2::GreenLanes::GoodsNomenclatureSerializer.new(presented_gn, include: %w[applicable_measures possible_categorisations])

          render json: serializer.serializable_hash
        end
      end
    end
  end
end

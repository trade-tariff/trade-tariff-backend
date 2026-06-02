module Api
  module Admin
    module GoodsNomenclatureLabels
      class StatsController < AdminController
        def show
          stats = StatsService.new.call

          render json: StatsSerializer.new(stats).serializable_hash
        end
      end
    end
  end
end

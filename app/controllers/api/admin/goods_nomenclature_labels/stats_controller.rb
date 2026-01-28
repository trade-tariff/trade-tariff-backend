module Api
  module Admin
    module GoodsNomenclatureLabels
      class StatsController < AdminController
        def show
          stats = StatsService.new.call
          stats_object = OpenStruct.new(stats)

          render json: StatsSerializer.new(stats_object).serializable_hash
        end
      end
    end
  end
end

module Api
  module V2
    class DeltasController < ApiController
      def index
        render json: Api::V2::DeltasSerializer.new(deltas).serializable_hash
      end

      private

      def deltas
        Delta.where(delta_date: Delta.point_in_time).all
      end
    end
  end
end

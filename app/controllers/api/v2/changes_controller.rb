module Api
  module V2
    class ChangesController < ApiController
      def index
        render json: Api::V2::ChangesSerializer.new(changes).serializable_hash
      end

      private

      def changes
        Change.where(change_date: Change.point_in_time).all
      end
    end
  end
end

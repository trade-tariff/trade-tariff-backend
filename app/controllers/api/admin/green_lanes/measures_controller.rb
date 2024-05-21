module Api
  module Admin
    module GreenLanes
      class MeasuresController < AdminController
        include XiOnly

        before_action :check_service, :authenticate_user!

        def index
          render json: serialize(measures.to_a)
        end

        private

        def measures
          @measures ||= ::GreenLanes::Measure.order(Sequel.asc(:id))
        end

        def serialize(*args)
          Api::Admin::GreenLanes::MeasureSerializer.new(*args).serializable_hash
        end
      end
    end
  end
end

module Api
  module Admin
    module GreenLanes
      class ExemptionsController < AdminController
        include XiOnly

        before_action :check_service, :authenticate_user!

        def index
          render json: serialize(exemptions.to_a)
        end

        def show
          ex = ::GreenLanes::Exemption.with_pk!(params[:id])
          render json: serialize(ex)
        end

        private

        def exemptions
          @exemptions ||= ::GreenLanes::Exemption.order(Sequel.asc(:code))
        end

        def serialize(*args)
          Api::Admin::GreenLanes::ExemptionSerializer.new(*args).serializable_hash
        end
      end
    end
  end
end

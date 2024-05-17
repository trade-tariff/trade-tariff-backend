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

        def create
          ex = ::GreenLanes::Exemption.new(exemption_params)

          if ex.valid? && ex.save
            render json: serialize(ex),
                   location: api_admin_green_lanes_exemption_url(ex.id),
                   status: :created
          else
            render json: serialize_errors(ex),
                   status: :unprocessable_entity
          end
        end

        def update
          ex = ::GreenLanes::Exemption.with_pk!(params[:id])
          ex.set exemption_params

          if ex.valid? && ex.save
            render json: serialize(ex),
                   location: api_admin_green_lanes_exemption_url(ex.id),
                   status: :ok
          else
            render json: serialize_errors(ex),
                   status: :unprocessable_entity
          end
        end

        def destroy
          ex = ::GreenLanes::Exemption.with_pk!(params[:id])
          ex.destroy

          head :no_content
        end

        private

        def exemption_params
          params.require(:data).require(:attributes).permit(
            :code,
            :description,
          )
        end

        def exemptions
          @exemptions ||= ::GreenLanes::Exemption.order(Sequel.asc(:code))
        end

        def serialize(*args)
          Api::Admin::GreenLanes::ExemptionSerializer.new(*args).serializable_hash
        end

        def serialize_errors(exemption)
          Api::Admin::ErrorSerializationService.new(exemption).call
        end
      end
    end
  end
end

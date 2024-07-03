module Api
  module Admin
    module GreenLanes
      class ExemptingAdditionalCodeOverridesController < AdminController
        include Pageable
        include XiOnly

        before_action :check_service, :authenticate_user!

        def index
          render json: serialize(exempting_additional_code_override.to_a, pagination_meta)
        end

        def show
          eco = ::GreenLanes::ExemptingAdditionalCodeOverride.with_pk!(params[:id])
          render json: serialize(eco)
        end

        def create
          eco = ::GreenLanes::ExemptingAdditionalCodeOverride.new(eco_params)

          if eco.valid? && eco.save
            render json: serialize(eco),
                   location: api_admin_green_lanes_exempting_additional_code_override_url(eco.id),
                   status: :created
          else
            render json: serialize_errors(eco),
                   status: :unprocessable_entity
          end
        end

        def destroy
          eco = ::GreenLanes::ExemptingAdditionalCodeOverride.with_pk!(params[:id])
          eco.destroy

          head :no_content
        end

        private

        def eco_params
          params.require(:data).require(:attributes).permit(
            :additional_code_type_id,
            :additional_code,
          )
        end

        def record_count
          @exempting_additional_code_override.pagination_record_count
        end

        def exempting_additional_code_override
          @exempting_additional_code_override ||= ::GreenLanes::ExemptingAdditionalCodeOverride.order(Sequel.asc(:additional_code_type_id), Sequel.asc(:additional_code)).paginate(current_page, per_page)
        end

        def serialize(*args)
          Api::Admin::GreenLanes::ExemptingAdditionalCodeOverrideSerializer.new(*args).serializable_hash
        end

        def serialize_errors(exempting_additional_code_override)
          Api::Admin::ErrorSerializationService.new(exempting_additional_code_override).call
        end
      end
    end
  end
end

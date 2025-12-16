module Api
  module Admin
    module GreenLanes
      class ExemptingCertificateOverridesController < AdminController
        include Pageable
        include XiOnly

        def index
          render json: serialize(exempting_certificate_override.to_a, pagination_meta)
        end

        def show
          eco = ::GreenLanes::ExemptingCertificateOverride.with_pk!(params[:id])
          render json: serialize(eco)
        end

        def create
          eco = ::GreenLanes::ExemptingCertificateOverride.new(eco_params)

          if eco.valid? && eco.save
            render json: serialize(eco),
                   status: :created
          else
            render json: serialize_errors(eco),
                   status: :unprocessable_content
          end
        end

        def destroy
          eco = ::GreenLanes::ExemptingCertificateOverride.with_pk!(params[:id])
          eco.destroy

          head :no_content
        end

        private

        def eco_params
          params.require(:data).require(:attributes).permit(
            :certificate_type_code,
            :certificate_code,
          )
        end

        def record_count
          @exempting_certificate_override.pagination_record_count
        end

        def exempting_certificate_override
          @exempting_certificate_override ||= ::GreenLanes::ExemptingCertificateOverride.order(Sequel.asc(:certificate_type_code), Sequel.asc(:certificate_code)).paginate(current_page, per_page)
        end

        def serialize(*args)
          Api::Admin::GreenLanes::ExemptingCertificateOverrideSerializer.new(*args).serializable_hash
        end

        def serialize_errors(exempting_certificate_override)
          Api::Admin::ErrorSerializationService.new(exempting_certificate_override).call
        end
      end
    end
  end
end

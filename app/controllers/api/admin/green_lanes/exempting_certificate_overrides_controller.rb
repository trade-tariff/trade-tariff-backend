module Api
  module Admin
    module GreenLanes
      class ExemptingCertificateOverridesController < AdminController
        include Pageable
        include XiOnly
        include Api::Admin::ResourceActions

        def index
          render json: serialize(collection.to_a, pagination_meta)
        end

        private

        def serializer_class = Api::Admin::GreenLanes::ExemptingCertificateOverrideSerializer
        def resource_class = ::GreenLanes::ExemptingCertificateOverride

        def resource_params
          params.require(:data).require(:attributes).permit(
            :certificate_type_code,
            :certificate_code,
          )
        end

        def record_count
          collection.pagination_record_count
        end

        def collection
          @collection ||= ::GreenLanes::ExemptingCertificateOverride
            .order(Sequel.asc(:certificate_type_code), Sequel.asc(:certificate_code))
            .paginate(current_page, per_page)
        end
      end
    end
  end
end

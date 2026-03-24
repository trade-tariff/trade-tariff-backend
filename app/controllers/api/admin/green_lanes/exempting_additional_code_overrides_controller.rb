module Api
  module Admin
    module GreenLanes
      class ExemptingAdditionalCodeOverridesController < AdminController
        include Pageable
        include XiOnly
        include Api::Admin::ResourceActions

        def index
          render json: serialize(collection.to_a, pagination_meta)
        end

        private

        def serializer_class = Api::Admin::GreenLanes::ExemptingAdditionalCodeOverrideSerializer
        def resource_class = ::GreenLanes::ExemptingAdditionalCodeOverride

        def resource_params
          params.require(:data).require(:attributes).permit(
            :additional_code_type_id,
            :additional_code,
          )
        end

        def record_count
          collection.pagination_record_count
        end

        def collection
          @collection ||= ::GreenLanes::ExemptingAdditionalCodeOverride
            .order(Sequel.asc(:additional_code_type_id), Sequel.asc(:additional_code))
            .paginate(current_page, per_page)
        end
      end
    end
  end
end

module Api
  module Admin
    module GreenLanes
      class MeasureTypeMappingsController < AdminController
        include Pageable
        include XiOnly
        include Api::Admin::ResourceActions

        def index
          options = { is_collection: true, include: %i[theme], meta: pagination_meta(collection) }
          render json: serialize(collection.to_a, options)
        end

        private

        def serializer_class = Api::Admin::GreenLanes::MeasureTypeMappingSerializer
        def resource_class = ::GreenLanes::IdentifiedMeasureTypeCategoryAssessment

        def resource_params
          params.require(:data).require(:attributes).permit(:measure_type_id, :theme_id)
        end

        def pagination_meta(data_set)
          {
            pagination: {
              page: current_page,
              per_page:,
              total_count: data_set.pagination_record_count,
            },
          }
        end

        def collection
          @collection ||= ::GreenLanes::IdentifiedMeasureTypeCategoryAssessment
            .eager(:theme)
            .order(Sequel.asc(:measure_type_id))
            .paginate(current_page, per_page)
        end
      end
    end
  end
end

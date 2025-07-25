module Api
  module Admin
    module GreenLanes
      class MeasureTypeMappingsController < AdminController
        include Pageable
        include XiOnly

        before_action :check_service, :authenticate_user!

        def index
          options = { is_collection: true }
          options[:include] = %i[theme]
          options[:meta] = pagination_meta(measure_type_mappings)
          render json: serialize(measure_type_mappings.to_a, options)
        end

        def show
          ex = ::GreenLanes::IdentifiedMeasureTypeCategoryAssessment.with_pk!(params[:id])
          render json: serialize(ex)
        end

        def create
          ex = ::GreenLanes::IdentifiedMeasureTypeCategoryAssessment.new(measure_type_mapping_params)

          if ex.valid? && ex.save
            render json: serialize(ex),
                   status: :created
          else
            render json: serialize_errors(ex),
                   status: :unprocessable_entity
          end
        end

        def destroy
          ex = ::GreenLanes::IdentifiedMeasureTypeCategoryAssessment.with_pk!(params[:id])
          ex.destroy

          head :no_content
        end

        private

        def measure_type_mapping_params
          params.require(:data).require(:attributes).permit(
            :measure_type_id,
            :theme_id,
          )
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

        def measure_type_mappings
          @measure_type_mappings ||= ::GreenLanes::IdentifiedMeasureTypeCategoryAssessment
                                       .eager(:theme)
                                       .order(Sequel.asc(:measure_type_id))
                                       .paginate(current_page, per_page)
        end

        def serialize(*args)
          Api::Admin::GreenLanes::MeasureTypeMappingSerializer.new(*args).serializable_hash
        end

        def serialize_errors(measure_type_mapping)
          Api::Admin::ErrorSerializationService.new(measure_type_mapping).call
        end
      end
    end
  end
end

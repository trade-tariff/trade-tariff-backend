module Api
  module Admin
    module GreenLanes
      class MeasuresController < AdminController
        include Pageable
        include XiOnly

        MEASURE_EAGER_GRAPH = {
          category_assessment: :theme,
          goods_nomenclature: :goods_nomenclature_descriptions,
        }.freeze

        before_action :check_service, :authenticate_user!

        def index
          options = { is_collection: true }
          options[:include] = %i[category_assessment category_assessment.theme goods_nomenclature]
          options[:meta] = pagination_meta(measures)
          render json: serialize(measures.to_a, options)
        end

        private

        def measures
          @measures ||= ::GreenLanes::Measure.eager(MEASURE_EAGER_GRAPH).order.paginate(current_page, per_page)
        end

        def record_count
          @measures.pagination_record_count
        end

        def serialize(*args)
          Api::Admin::GreenLanes::MeasureSerializer.new(*args).serializable_hash
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
      end
    end
  end
end

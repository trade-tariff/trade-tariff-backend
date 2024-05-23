module Api
  module Admin
    module GreenLanes
      class MeasuresController < AdminController
        include XiOnly

        MEASURE_EAGER_GRAPH = {
          category_assessment: :theme,
          goods_nomenclature: :goods_nomenclature_descriptions,
        }.freeze

        before_action :check_service, :authenticate_user!

        def index
          options = { is_collection: true }
          options[:include] = %i[category_assessment category_assessment.theme goods_nomenclature]
          render json: serialize(measures.to_a, options)
        end

        private

        def measures
          @measures ||= ::GreenLanes::Measure.eager(MEASURE_EAGER_GRAPH).all
        end

        def serialize(*args)
          Api::Admin::GreenLanes::MeasureSerializer.new(*args).serializable_hash
        end
      end
    end
  end
end

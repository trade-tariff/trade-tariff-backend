module Api
  module Admin
    module GreenLanes
      class CategoryAssessmentsController < AdminController
        include Pageable

        before_action :authenticate_user!

        def index
          render json: serialize(category_assessments.to_a, pagination_meta)
        end

        private

        def record_count
          @category_assessments.pagination_record_count
        end

        def category_assessments
          @category_assessments ||= ::GreenLanes::CategoryAssessment.order(Sequel.desc(:id)).paginate(current_page, per_page)
        end

        def serialize(*args)
          Api::Admin::GreenLanes::CategoryAssessmentSerializer.new(*args).serializable_hash
        end
      end
    end
  end
end

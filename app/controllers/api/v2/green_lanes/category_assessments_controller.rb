module Api
  module V2
    module GreenLanes
      class CategoryAssessmentsController < BaseController
        def index
          category_assessment = ::GreenLanes::CategoryAssessment.load_category_assessment
          serializer = Api::V2::GreenLanes::CategoryAssessmentSerializer.new(category_assessment, include: %w[geographical_area])

          render json: serializer.serializable_hash
        end
      end
    end
  end
end

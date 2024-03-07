module Api
  module V2
    module GreenLanes
      class CategoryAssessmentsController < BaseController
        def index
          category_assessments = ::GreenLanes::CategoryAssessmentJson.all
          serializer = Api::V2::GreenLanes::CategoryAssessmentSerializer.new(category_assessments, include: %w[geographical_area excluded_geographical_areas])

          render json: serializer.serializable_hash
        end
      end
    end
  end
end

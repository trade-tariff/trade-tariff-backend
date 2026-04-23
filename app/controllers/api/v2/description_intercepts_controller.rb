module Api
  module V2
    class DescriptionInterceptsController < ApiController
      def index
        render json: Api::V2::DescriptionInterceptSerializer.new(description_intercepts).serializable_hash
      end

      private

      def description_intercepts
        DescriptionIntercept
          .for_source(params[:source])
          .matching_excluded(params[:excluded])
          .order(Sequel.asc(:term), Sequel.asc(:id))
          .all
      end
    end
  end
end

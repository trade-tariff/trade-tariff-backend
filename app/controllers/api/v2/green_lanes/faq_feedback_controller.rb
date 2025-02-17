module Api
  module V2
    module GreenLanes
      class FaqFeedbackController < BaseController
        include V2Api.routes.url_helpers

        skip_before_action :check_service

        def create
          faq_feedback = ::GreenLanes::FaqFeedback.new(faq_feedback_params)

          if faq_feedback.valid? && faq_feedback.save
            render json: serialize(faq_feedback),
                   location: api_green_lanes_faq_feedback_url(faq_feedback.id),
                   status: :created
          else
            render json: serialize_errors(faq_feedback),
                   status: :unprocessable_entity
          end
        end

        def index
          faq_feedback = ::GreenLanes::FaqFeedback.all
          render json: serialize(faq_feedback)
        end

        private

        def faq_feedback_params
          params.require(:data).require(:attributes).permit(
            :session_id,
            :category_id,
            :question_id,
            :useful,
          )
        end

        def serialize(*args)
          Api::V2::GreenLanes::FaqFeedbackSerializer.new(*args).serializable_hash
        end

        def serialize_errors(faq_feedback)
          Api::V2::ErrorSerializationService.new.serialized_errors(faq_feedback.errors)
        end
      end
    end
  end
end

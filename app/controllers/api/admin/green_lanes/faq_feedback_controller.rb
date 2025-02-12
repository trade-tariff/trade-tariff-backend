module Api
  module Admin
    module GreenLanes
      class FaqFeedbackController < AdminController
        before_action :authenticate_user!

        def create
          faq_feedback = ::GreenLanes::FaqFeedback.new(faq_feedback_params)
          Rails.logger.info("FAQ feedback valid?: #{faq_feedback.valid?}")
          if faq_feedback.valid? && faq_feedback.save
            Rails.logger.info("FAQ feedback created: #{faq_feedback.id}")
            render json: serialize(faq_feedback),
                   location: api_admin_green_lanes_faq_feedback_url(faq_feedback.id),
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
          Api::Admin::GreenLanes::FaqFeedbackSerializer.new(*args).serializable_hash
        end

        def serialize_errors(exemption)
          Api::Admin::ErrorSerializationService.new(exemption).call
        end
      end
    end
  end
end

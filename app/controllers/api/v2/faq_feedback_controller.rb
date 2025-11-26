module Api
  module V2
    class FaqFeedbackController < ApiController
      include ApiTokenAuthenticatable

      before_action :authenticate!

      def index
        faq_feedback = FaqFeedback.all
        render json: serialize(faq_feedback)
      end

      def create
        faq_feedback = FaqFeedback.new(faq_feedback_params)

        if faq_feedback.valid? && faq_feedback.save
          render json: serialize(faq_feedback), status: :created
        else
          render json: serialize_errors(faq_feedback), status: :unprocessable_content
        end
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
        Api::V2::FaqFeedbackSerializer.new(*args).serializable_hash
      end

      def serialize_errors(faq_feedback)
        Api::V2::ErrorSerializationService.new.serialized_errors(faq_feedback.errors)
      end
    end
  end
end

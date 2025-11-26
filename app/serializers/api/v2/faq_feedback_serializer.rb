module Api
  module V2
    class FaqFeedbackSerializer
      include JSONAPI::Serializer

      set_type :green_lanes_faq_feedback

      set_id :id

      attributes :session_id,
                 :category_id,
                 :question_id,
                 :useful
    end
  end
end

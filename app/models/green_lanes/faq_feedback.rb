module GreenLanes
  class FaqFeedback < Sequel::Model(:green_lanes_faq_feedback)
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence

    # Ensure uniqueness of the composite key
    def validate
      super
      validates_unique(%i[session_id category_id question_id])
    end
  end
end

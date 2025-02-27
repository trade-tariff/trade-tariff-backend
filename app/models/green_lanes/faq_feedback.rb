module GreenLanes
  class FaqFeedback < Sequel::Model(:green_lanes_faq_feedback)
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence

    # Ensure uniqueness of the composite key
    def validate
      super
      validates_unique(%i[session_id category_id question_id])
    end

    def self.statistics
      GreenLanes::FaqFeedback
               .select(:category_id, :question_id,
                       Sequel.as(Sequel.lit('SUM(CASE WHEN useful THEN 1 ELSE 0 END)'), :useful_count),
                       Sequel.as(Sequel.lit('SUM(CASE WHEN useful THEN 0 ELSE 1 END)'), :not_useful_count))
               .group(:category_id, :question_id)
               .order(:category_id, :question_id)
    end
  end
end

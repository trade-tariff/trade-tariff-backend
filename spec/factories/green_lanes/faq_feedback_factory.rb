FactoryBot.define do
  factory :green_lanes_faq_feedback, class: 'GreenLanes::FaqFeedback' do
    session_id { SecureRandom.uuid }
    category_id { 1 }
    question_id { 1 }
    useful { true }
  end
end

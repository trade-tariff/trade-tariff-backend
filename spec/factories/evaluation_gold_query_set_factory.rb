FactoryBot.define do
  factory :evaluation_gold_query_set do
    sequence(:name) { |n| "gold_set_#{n}" }
    requested_size { 3 }
    atar_percentage { 100 }
    planned_count { 3 }
    generated_count { 0 }
    failed_count { 0 }
    status { 'generating' }
    created_by { 'user-123' }
  end
end

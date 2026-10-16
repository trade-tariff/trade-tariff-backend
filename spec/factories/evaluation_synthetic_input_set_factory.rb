FactoryBot.define do
  factory :evaluation_synthetic_input_set do
    sequence(:name) { |n| "synthetic_input_set_#{n}" }
    requested_size { 3 }
    actual_size { 3 }
    created_by { 'user-123' }
  end
end

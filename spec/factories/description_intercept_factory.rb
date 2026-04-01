FactoryBot.define do
  factory :description_intercept do
    term { 'footwear' }
    sources { Sequel.pg_array(%w[guided_search], :text) }
    message { 'Please be more specific.' }
    excluded { false }
  end
end

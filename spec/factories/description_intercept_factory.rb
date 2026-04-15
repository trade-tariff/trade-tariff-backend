FactoryBot.define do
  factory :description_intercept do
    term { 'footwear' }
    sources { Sequel.pg_array(%w[guided_search], :text) }
    message { 'Please be more specific.' }
    guidance_level { nil }
    guidance_location { nil }
    escalate_to_webchat { false }
    filter_prefixes { nil }
    excluded { false }
  end
end

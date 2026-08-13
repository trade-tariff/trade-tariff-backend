FactoryBot.define do
  factory :evaluation_gold_query do
    sequence(:source_id) { |n| "60000#{n}" }
    source_type { 'atar' }
    persona { 'emu_generic' }
    query { 'cotton bed linen' }
    expected_code { '6302100000' }
  end
end

FactoryBot.define do
  factory :evaluation_gold_query do
    evaluation_gold_query_set { create(:evaluation_gold_query_set) }
    sequence(:source_id) { |n| "60000#{n}" }
    source_type { 'atar' }
    persona { 'emu_generic' }
    query { 'cotton bed linen' }
    expected_code { '6302100000' }
    oracle_text { 'Bed linen woven from cotton fabric, printed with a floral pattern.' }
  end
end

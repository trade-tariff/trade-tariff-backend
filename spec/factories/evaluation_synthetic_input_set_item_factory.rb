FactoryBot.define do
  factory :evaluation_synthetic_input_set_item do
    evaluation_synthetic_input_set { create(:evaluation_synthetic_input_set) }
    synthetic_atar_id { create(:tariff_knowledge_synthetic_atar).id }
    query { 'Reusable plastic food storage box with a clip-on lid, made of polypropylene, for household use.' }
    expected_code { '3924100000' }
  end
end

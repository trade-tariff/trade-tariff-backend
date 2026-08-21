FactoryBot.define do
  factory :evaluation_result do
    association :evaluation_run, strategy: :create
    source_type { 'atar' }
    source_id { "source_#{SecureRandom.hex(4)}" }
    persona { 'original' }
    expected_code { '8471300000' }
  end
end

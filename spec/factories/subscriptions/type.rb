FactoryBot.define do
  factory :type do
    name { 'test' }
    description { 'test' }
    created_at { Time.zone.now }
    updated_at { Time.zone.now }
  end
end

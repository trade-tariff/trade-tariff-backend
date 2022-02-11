FactoryBot.define do
  factory :measure_action_description do
    action_code { Forgery(:basic).text(exactly: 2) }
    language_id { 'EN' }
    description { 'Import/export not allowed after control' }
  end
end

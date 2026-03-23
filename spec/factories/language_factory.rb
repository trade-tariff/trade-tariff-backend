FactoryBot.define do
  factory :language_description do
    language_code_id   { generate(:language_id) }
    language_id        { generate(:language_id) }
    description        { Forgery(:basic).text }
  end
end

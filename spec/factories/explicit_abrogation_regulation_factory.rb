FactoryBot.define do
  factory :explicit_abrogation_regulation do
    explicit_abrogation_regulation_role { 8 }
    explicit_abrogation_regulation_id   { Forgery(:basic).text(exactly: 8) }

    published_date                      { Time.zone.now.ago(2.years) }
  end
end

FactoryBot.define do
  factory :regulation_group do
    regulation_group_id     { Forgery(:basic).text(exactly: 3) }
    validity_start_date     { 2.years.ago.beginning_of_day }
    validity_end_date       { nil }
  end
end

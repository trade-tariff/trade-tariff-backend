FactoryBot.define do
  factory :meursing_table_plan do
    meursing_table_plan_id          { Forgery(:basic).text(exactly: 2) }
    validity_start_date             { 2.years.ago.beginning_of_day }
    validity_end_date               { nil }
  end
end

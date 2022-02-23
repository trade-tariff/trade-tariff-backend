FactoryBot.define do
  factory :meursing_heading do
    meursing_table_plan_id          { Forgery(:basic).text(exactly: 2) }
    meursing_heading_number         { Forgery(:basic).number }
    row_column_code                 { Forgery(:basic).number }
    validity_start_date             { 2.years.ago.beginning_of_day }
    validity_end_date               { nil }
  end
end

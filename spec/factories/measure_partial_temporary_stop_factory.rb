FactoryBot.define do
  factory :measure_partial_temporary_stop do
    partial_temporary_stop_regulation_id { Forgery(:basic).text(exactly: 8) }
    measure_sid { generate(:measure_sid) }
    abrogation_regulation_id             { Forgery(:basic).text(exactly: 8) }
    validity_start_date                  { Time.zone.now.ago(2.years) }
    validity_end_date                    { nil }
  end
end

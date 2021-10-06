FactoryBot.define do
  factory :fts_regulation, class: 'FullTemporaryStopRegulation' do
    full_temporary_stop_regulation_role { Forgery(:basic).number }
    full_temporary_stop_regulation_id   { Forgery(:basic).text(exactly: 8) }
    validity_start_date                 { Time.zone.now.ago(2.years) }
    validity_end_date                   { nil }
    effective_enddate                   { nil }
  end

  factory :fts_regulation_action do
    fts_regulation_role     { Forgery(:basic).number }
    fts_regulation_id       { Forgery(:basic).text(exactly: 8) }
    stopped_regulation_role { Forgery(:basic).number }
    stopped_regulation_id   { Forgery(:basic).text(exactly: 8) }
  end
end

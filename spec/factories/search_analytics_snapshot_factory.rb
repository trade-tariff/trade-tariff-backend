FactoryBot.define do
  factory :search_analytics_snapshot do
    service { 'uk' }
    period { '24h' }
    view { 'all' }
    bucket_size { 'hour' }
    generated_at { Time.zone.parse('2026-06-10 09:55:00 UTC') }
    data_through { Time.zone.parse('2026-06-10 09:50:00 UTC') }
    payload do
      {
        'summary' => {
          'searches' => 1_240,
          'failure_rate' => 0.012,
        },
      }
    end
  end
end

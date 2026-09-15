FactoryBot.define do
  factory :search_analytics_collection do
    service { TradeTariffBackend.service }
    source { 'cloudwatch' }
    reporting_date { Date.new(2026, 9, 14) }
    definition_version { SearchAnalyticsDay::DEFINITION_VERSION }
    window_start { reporting_date.to_time(:utc) }
    window_end { window_start + 1.day }
    log_group_name { 'platform-logs-production' }
    region { 'eu-west-2' }
    status { 'complete' }
    price_per_gb_usd { 0.005 }
    started_at { window_end + 4.hours }
    finished_at { started_at + 1.minute }
  end

  factory :search_analytics_day do
    service { TradeTariffBackend.service }
    source { 'cloudwatch' }
    reporting_date { Date.new(2026, 9, 14) }
    definition_version { SearchAnalyticsDay::DEFINITION_VERSION }
    published_at { reporting_date.to_time(:utc) + 28.hours }
    collection_id { create(:search_analytics_collection, service:, source:, reporting_date:, definition_version:).id }
    facts { Sequel.pg_jsonb({}) }
  end
end

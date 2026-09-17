# frozen_string_literal: true

FactoryBot.define do
  factory :search_analytics_read_model do
    service { TradeTariffBackend.service }
    region { 'eu-west-2' }
    version { SearchAnalyticsReadModel::VERSION }
    fingerprints { { 'search_journeys' => 'journeys-fingerprint', 'journey_outcomes' => 'outcomes-fingerprint' } }
    source_versions { {} }
    built_at { Time.utc(2026, 9, 15, 10) }
  end
end

# frozen_string_literal: true

module SearchAnalytics
  class DailyJourney < Sequel::Model(:search_analytics_daily_journeys)
    include MaterializedView

    set_primary_key %i[service reporting_date journey_key]
  end
end

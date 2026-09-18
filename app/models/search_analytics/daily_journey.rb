# frozen_string_literal: true

module SearchAnalytics
  # Exists because journey JSON is too large to decode on each dashboard read.
  # Collapse each hashed identity to one row per service and UTC date so later
  # steps work from compact keys, hours, outcomes and flags.
  class DailyJourney < Sequel::Model(:search_analytics_daily_journeys)
    include MaterializedView

    set_primary_key %i[service reporting_date journey_key]
  end
end

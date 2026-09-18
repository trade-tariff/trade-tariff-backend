# frozen_string_literal: true

module SearchAnalytics
  # Exists because unique journeys cannot be summed across days.
  # Keep only identities that appear on more than one date so a range can count
  # them once without scanning every daily journey.
  class RepeatedJourney < Sequel::Model(:search_analytics_repeated_journeys)
    include MaterializedView

    set_primary_key %i[service reporting_date journey_key]
  end
end

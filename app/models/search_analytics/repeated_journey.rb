# frozen_string_literal: true

module SearchAnalytics
  # Daily journey rows whose hashed identity appears on more than one date.
  # Same columns as DailyJourney. Range reads combine these leftovers so a
  # journey spanning days is counted once. Journeys that never repeat are not
  # stored here; their counts live in JourneyRollupTotal.
  class RepeatedJourney < Sequel::Model(:search_analytics_repeated_journeys)
    include MaterializedView

    set_primary_key %i[service reporting_date journey_key]
  end
end

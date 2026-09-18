# frozen_string_literal: true

module SearchAnalytics
  # Exists because most journeys never leave one date.
  # Pre-count those single-date identities by view and day or hour so a long
  # range adds small totals instead of visiting millions of keys.
  class JourneyRollupTotal < Sequel::Model(:search_analytics_journey_rollup_totals)
    include MaterializedView

    set_primary_key %i[service reporting_date view bucket_size bucket]
  end
end

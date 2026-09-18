# frozen_string_literal: true

module SearchAnalytics
  # Pre-summed counts for journeys that exist on only one date.
  # One row per service, date, view (all, classic, internal), bucket size (day
  # or hour) and bucket time. Columns are journey counts plus completed, failed,
  # nonterminal, unknown, selected and zero_result. A dashboard range can add
  # these totals, then mix in RepeatedJourney for identities that cross days.
  class JourneyRollupTotal < Sequel::Model(:search_analytics_journey_rollup_totals)
    include MaterializedView

    set_primary_key %i[service reporting_date view bucket_size bucket]
  end
end

# frozen_string_literal: true

module SearchAnalytics
  class JourneyRollupTotal < Sequel::Model(:search_analytics_journey_rollup_totals)
    include MaterializedView

    set_primary_key %i[service reporting_date view bucket_size bucket]
  end
end

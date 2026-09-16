# frozen_string_literal: true

module SearchAnalytics
  class LatencyStatus
    # Internal thresholds are provisional, informed by the AI-1077 pilot, not an SLA.
    LIMITS_MS = { 'classic' => [250, 500], 'internal' => [25_000, 35_000] }.freeze

    def self.call(value:, view:)
      return { 'level' => 'neutral', 'message' => 'Percentile unavailable for this combination of data' } if value.nil?
      return { 'level' => 'neutral', 'message' => 'Mixed search types: use Classic or Internal to assess latency' } if view == 'all'

      good_limit, problem_limit = LIMITS_MS.fetch(view)
      name = view == 'classic' ? 'classic search' : 'AI-assisted search'
      if value <= good_limit
        { 'level' => 'good', 'message' => "P90 is within the current latency threshold for #{name}" }
      elsif value / LatencyHistogram::BASE > problem_limit
        # The stored estimate is a bin's upper bound. Red requires its lower
        # bound to exceed the limit too, rather than penalising approximation.
        { 'level' => 'problem', 'message' => "P90 exceeds the problem threshold for #{name}, allowing for histogram approximation" }
      else
        { 'level' => 'watch', 'message' => "P90 is above the good threshold for #{name}, but not clearly beyond the problem threshold" }
      end
    end
  end
end

# frozen_string_literal: true

module SearchAnalytics
  class RequestCosts
    def initialize(trend_rows:, journey_keys:)
      @rows = trend_rows.select { |row| journey_keys.key?(row.fetch('journey_key')) }
    end

    def call
      journeys = @rows.map { |row| row.fetch('journey_key') }.uniq.size
      total = @rows.sum(0.to_d) { |row| BigDecimal(row.fetch('total_cost_usd').to_s) }
      summary = {
        'assisted_searches' => journeys,
        'total_cost_usd' => total.to_s('F'),
        'average_cost_usd' => journeys.zero? ? 0 : (total / journeys).to_s('F'),
        'priced_calls' => @rows.sum { |row| row.fetch('priced_calls').to_i },
        'unpriced_calls' => @rows.sum { |row| row.fetch('unpriced_calls').to_i },
      }
      { summary:, trend: @rows }
    end
  end
end

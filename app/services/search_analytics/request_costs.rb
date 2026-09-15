# frozen_string_literal: true

module SearchAnalytics
  class RequestCosts
    def initialize(summary_rows:, trend_rows:, journey_keys:)
      @summaries = summary_rows
      @trends = trend_rows
      @journey_keys = journey_keys
    end

    def call
      validate!
      grouped = @summaries.group_by { |row| row.fetch('journey_key') }
      selected = grouped.select { |key, rows| billable_events?(rows) && @journey_keys.key?(key) }
      rows = selected.values.flatten
      total = sum(rows, 'total_cost_usd')
      summary = {
        'assisted_searches' => selected.size,
        'total_cost_usd' => total.to_s('F'),
        'average_cost_usd' => selected.empty? ? 0 : (total / selected.size).to_s('F'),
        'priced_calls' => rows.sum { |row| row.fetch('priced_calls').to_i },
        'unpriced_calls' => rows.sum { |row| row.fetch('unpriced_calls').to_i },
      }
      { summary:, trend: @trends.select { |row| selected.key?(row.fetch('journey_key')) } }
    end

  private

    def billable_events?(rows) = (sum(rows, 'priced_calls') + sum(rows, 'unpriced_calls')).positive?

    def sum(rows, field) = rows.sum(0.to_d) { |row| BigDecimal(row.fetch(field).to_s) }

    def validate!
      summaries = @summaries.group_by { |row| row.fetch('journey_key') }
      trends = @trends.group_by { |row| row.fetch('journey_key') }
      raise ArgumentError, 'Cost queries disagree on request identifiers' if (trends.keys - summaries.keys).any?

      summaries.each do |key, rows|
        request_trends = trends.fetch(key, [])
        %w[priced_calls unpriced_calls].each do |field|
          raise ArgumentError, "Cost queries disagree on #{field}" unless sum(rows, field) == sum(request_trends, field)
        end
        if (sum(rows, 'total_cost_usd') - sum(request_trends, 'total_cost_usd')).abs > BigDecimal('0.000000000001')
          raise ArgumentError, 'Cost queries disagree on recorded costs'
        end
      end
    end
  end
end

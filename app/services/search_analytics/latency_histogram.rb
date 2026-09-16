# frozen_string_literal: true

module SearchAnalytics
  class LatencyHistogram
    RELATIVE_WIDTH = 0.05
    BASE = 1 + RELATIVE_WIDTH
    LOG_BASE = Math.log(BASE)
    ZERO_BUCKET = -1_000_000
    DEFINITION = { 'base' => BASE, 'zero_bucket' => ZERO_BUCKET, 'unit' => 'milliseconds' }.freeze

    def self.bucket(value)
      return ZERO_BUCKET if value.zero?

      (Math.log(value) / LOG_BASE).floor
    end

    def self.upper_bound(bucket)
      bucket == ZERO_BUCKET ? 0.0 : BASE**(bucket + 1)
    end

    # Nearest-rank percentile, reported as the containing bin's upper bound.
    # Combine counts before selecting the rank, never average daily percentiles.
    def self.percentile(rows, percentile: 90)
      counts = rows.group_by { |row| Float(row.fetch('latency_bucket')).to_i }
        .transform_values { |values| values.sum { |row| Float(row.fetch('observations')).to_i } }
      total = counts.values.sum
      return if total.zero?

      cumulative = 0
      counts.sort.each do |bucket, count|
        cumulative += count
        return upper_bound(bucket) if cumulative * 100 >= total * percentile
      end
    end
  end
end

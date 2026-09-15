# frozen_string_literal: true

class SearchAnalyticsCollection < Sequel::Model
  def self.cost_for_day(reporting_date:, service: TradeTariffBackend.service, source: 'cloudwatch')
    attempts = where(reporting_date:, service:, source:).all
    summaries = attempts.map(&:cost_summary)
    {
      'attempts' => attempts.size,
      'known_bytes_scanned' => summaries.sum { |summary| summary.fetch('known_bytes_scanned') },
      'known_estimated_cost_usd' => summaries.sum(0.to_d) { |summary| BigDecimal(summary.fetch('known_estimated_cost_usd')) }.to_s('F'),
      'cost_complete' => attempts.any? && summaries.all? { |summary| summary.fetch('cost_complete') },
    }
  end

  def cost_summary
    runs = SearchAnalyticsQueryRun.where(collection_id: id).all
    known_bytes = runs.sum { |run| run.bytes_scanned || 0 }
    complete = (runs.any? || query_results.present?) && runs.all? { |run| %w[Complete Failed Cancelled Timeout].include?(run.status) && !run.bytes_scanned.nil? }

    {
      'known_bytes_scanned' => known_bytes,
      'known_estimated_cost_usd' => (known_bytes.to_d / 1_000_000_000 * price_per_gb_usd).to_s('F'),
      'cost_complete' => complete && status != 'running',
      'price_per_gb_usd' => price_per_gb_usd.to_s('F'),
    }
  end
end

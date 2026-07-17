module Api
  module Admin
    class SearchAnalyticsSerializer
      include JSONAPI::Serializer

      EMPTY_AI_COSTS = {
        'summary' => {
          'total_cost_usd' => 0.0,
          'assisted_searches' => 0,
          'average_cost_usd' => 0.0,
          'p50_cost_usd' => 0.0,
          'p90_cost_usd' => 0.0,
          'priced_calls' => 0,
          'unpriced_calls' => 0,
          'pricing_coverage' => nil,
          'complete' => true,
        }.freeze,
        'trend' => [].freeze,
        'operations' => [].freeze,
      }.freeze

      set_type :search_analytics
      set_id { |snapshot| "#{snapshot.service}-#{snapshot.period}-#{snapshot.view}" }

      attributes :service, :period, :view, :bucket_size

      attribute(:generated_at) { |snapshot| snapshot.generated_at.iso8601 }
      attribute(:data_through) { |snapshot| snapshot.data_through.iso8601 }

      %w[summary summary_statuses trends comparisons request_sources].each do |name|
        attribute(name.to_sym) { |snapshot| snapshot.payload.fetch(name, {}) }
      end

      attribute(:ai_costs) { |snapshot| snapshot.payload.fetch('ai_costs', EMPTY_AI_COSTS) }

      attribute :improvement_terms do |snapshot|
        snapshot.payload.fetch('improvement_terms', [])
      end
    end
  end
end

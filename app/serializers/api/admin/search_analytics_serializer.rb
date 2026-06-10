module Api
  module Admin
    class SearchAnalyticsSerializer
      include JSONAPI::Serializer

      set_type :search_analytics
      set_id { |snapshot| "#{snapshot.service}-#{snapshot.period}-#{snapshot.view}" }

      attributes :service, :period, :view, :bucket_size

      attribute(:generated_at) { |snapshot| snapshot.generated_at.iso8601 }
      attribute(:data_through) { |snapshot| snapshot.data_through.iso8601 }

      %w[summary summary_statuses trends comparisons].each do |name|
        attribute(name.to_sym) { |snapshot| snapshot.payload.fetch(name, {}) }
      end

      attribute :improvement_terms do |snapshot|
        snapshot.payload.fetch('improvement_terms', [])
      end
    end
  end
end

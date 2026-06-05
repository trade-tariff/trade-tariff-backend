module Api
  module Admin
    module CustomsTariffPipeline
      class DashboardController < BaseController
        def show
          render json: {
            data: {
              id: 'current',
              type: 'customs_tariff_pipeline_dashboard',
              attributes: dashboard_attributes,
            },
          }
        end

        private

        def dashboard_attributes
          {
            latest_import_event: serialize_event(latest_event('import')),
            latest_publication_event: serialize_event(latest_event('publish')),
            review_backlog: serialize_metric_bin(latest_metric_bin('review_backlog')),
            open_alerts_count: filtered_alerts.open.count,
            metric_bins: filtered_metric_bins.all.map { |bin| serialize_metric_bin(bin) },
            open_alerts: filtered_alerts.open.limit(10).all.map { |alert| serialize_alert(alert) },
          }
        end

        def latest_event(event_type)
          filtered_events.where(event_type:).first
        end

        def latest_metric_bin(metric_name)
          filtered_metric_bins
            .where(metric_name:)
            .reverse(:bucket_start_at, :id)
            .first
        end

        def filtered_events
          @filtered_events ||= apply_time_range(CustomsTariffPipelineEvent.most_recent_first)
        end

        def filtered_metric_bins
          @filtered_metric_bins ||= begin
            dataset = CustomsTariffPipelineMetricBin.earliest_first
            dataset = apply_time_range(dataset)
            dataset = dataset.where(bucket_size: params[:bucket_size]) if params[:bucket_size].present?
            dataset
          end
        end

        def filtered_alerts
          @filtered_alerts ||= apply_time_range(CustomsTariffPipelineAlert.most_recent_first)
        end

        def serialize_event(event)
          return unless event

          EventSerializer.new(event).serializable_hash[:data][:attributes]
        end

        def serialize_metric_bin(metric_bin)
          return unless metric_bin

          MetricBinSerializer.new(metric_bin).serializable_hash[:data][:attributes]
        end

        def serialize_alert(alert)
          AlertSerializer.new(alert).serializable_hash[:data][:attributes]
        end
      end
    end
  end
end

module Api
  module Admin
    module CustomsTariffPipeline
      class AlertsController < BaseController
        def index
          page = filtered_alerts.paginate(current_page, per_page)

          render json: AlertSerializer.new(
            page.all,
            is_collection: true,
            meta: pagination_meta(page),
          ).serializable_hash
        end

        private

        def filtered_alerts
          dataset = CustomsTariffPipelineAlert.most_recent_first
          dataset = apply_time_range(dataset)
          apply_exact_filters(
            dataset,
            :alert_type,
            :severity,
            :status,
            :customs_tariff_update_version,
            :metric_name,
          )
        end
      end
    end
  end
end

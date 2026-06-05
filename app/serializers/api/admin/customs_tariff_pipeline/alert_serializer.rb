module Api
  module Admin
    module CustomsTariffPipeline
      class AlertSerializer
        include JSONAPI::Serializer

        set_type :customs_tariff_pipeline_alert

        attributes :alert_type, :severity, :status,
                   :customs_tariff_update_version, :metric_name,
                   :bucket_start_at, :triggered_at, :acknowledged_at,
                   :resolved_at, :acknowledged_by, :resolved_by,
                   :threshold_value, :observed_value, :message, :metadata,
                   :created_at, :updated_at
      end
    end
  end
end

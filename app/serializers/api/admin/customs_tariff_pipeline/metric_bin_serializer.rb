module Api
  module Admin
    module CustomsTariffPipeline
      class MetricBinSerializer
        include JSONAPI::Serializer

        set_type :customs_tariff_pipeline_metric_bin

        attributes :bucket_size, :bucket_start_at, :metric_name,
                   :customs_tariff_update_version, :event_type, :outcome,
                   :note_type, :count, :value_sum, :value_min, :value_max,
                   :value_last, :metadata, :created_at, :updated_at
      end
    end
  end
end

module Api
  module Admin
    module CustomsTariffPipeline
      class MetricBinsController < BaseController
        def index
          page = filtered_metric_bins.paginate(current_page, per_page)

          render json: MetricBinSerializer.new(
            page.all,
            is_collection: true,
            meta: pagination_meta(page),
          ).serializable_hash
        end

        private

        def filtered_metric_bins
          dataset = CustomsTariffPipelineMetricBin.earliest_first
          dataset = apply_time_range(dataset)
          apply_exact_filters(
            dataset,
            :bucket_size,
            :metric_name,
            :customs_tariff_update_version,
            :event_type,
            :outcome,
            :note_type,
          )
        end
      end
    end
  end
end

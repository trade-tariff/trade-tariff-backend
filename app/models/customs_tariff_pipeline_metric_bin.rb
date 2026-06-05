class CustomsTariffPipelineMetricBin < Sequel::Model
  dataset_module do
    def earliest_first
      order(:bucket_start_at, :metric_name, :id)
    end

    def from_time(time)
      where { bucket_start_at >= time }
    end

    def to_time(time)
      where { bucket_start_at <= time }
    end
  end
end

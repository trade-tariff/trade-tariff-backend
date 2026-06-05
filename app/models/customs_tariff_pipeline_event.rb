class CustomsTariffPipelineEvent < Sequel::Model
  dataset_module do
    def most_recent_first
      order(Sequel.desc(:occurred_at), Sequel.desc(:id))
    end

    def from_time(time)
      where { occurred_at >= time }
    end

    def to_time(time)
      where { occurred_at <= time }
    end
  end
end

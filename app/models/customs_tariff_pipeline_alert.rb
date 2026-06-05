class CustomsTariffPipelineAlert < Sequel::Model
  dataset_module do
    def most_recent_first
      order(Sequel.desc(:triggered_at), Sequel.desc(:id))
    end

    def from_time(time)
      where { triggered_at >= time }
    end

    def to_time(time)
      where { triggered_at <= time }
    end

    def open
      where(status: 'open')
    end
  end
end

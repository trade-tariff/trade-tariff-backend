class TradeTariffRequest < ActiveSupport::CurrentAttributes
  attribute :green_lanes,
            :time_machine_now,
            :time_machine_relevant,
            :meursing_additional_code_id
end

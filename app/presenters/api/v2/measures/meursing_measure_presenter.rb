module Api
  module V2
    module Measures
      class MeursingMeasurePresenter < SimpleDelegator
        def additional_code_id
          additional_code_sid
        end

        def measure_component_ids
          measure_components.map { |component| component.pk.join('-') }
        end
      end
    end
  end
end

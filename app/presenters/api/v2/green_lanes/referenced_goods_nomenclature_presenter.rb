# frozen_string_literal: true

module Api
  module V2
    module GreenLanes
      class ReferencedGoodsNomenclaturePresenter < WrapDelegator
        def measure_ids
          @measure_ids ||= measures.map(&:measure_sid)
        end

        def measures
          @measures ||= MeasurePresenter.wrap(super)
        end
      end
    end
  end
end

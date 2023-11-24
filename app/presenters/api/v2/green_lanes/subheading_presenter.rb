# frozen_string_literal: true

module Api
  module V2
    module GreenLanes
      class SubheadingPresenter < SimpleDelegator
        def applicable_measure_ids
          applicable_measures.map(&:id)
        end

        def applicable_measures
          super.map do |applicable_measure|
            Measures::MeasurePresenter.new(applicable_measure, self)
          end
        end
      end
    end
  end
end

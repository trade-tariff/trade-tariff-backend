# frozen_string_literal: true

module Api
  module V2
    module GreenLanes
      class GoodsNomenclaturePresenter < SimpleDelegator

        attr_reader :possible_categorisations

        def initialize(subheading, categories)
          super(subheading)
          @possible_categorisations = categories
        end

        def applicable_measure_ids
          applicable_measures.map(&:id)
        end

        def possible_categorisation_ids
          @possible_categorisation_ids ||= @possible_categorisations.map(&:id)
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

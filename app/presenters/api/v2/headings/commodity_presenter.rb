module Api
  module V2
    module Headings
      class CommodityPresenter < SimpleDelegator
        def initialize(commodity, overview_measures)
          @commodity = commodity
          @overview_measures = overview_measures

          super commodity
        end

        attr_accessor :leaf, :parent_sid # Managed by the AnnotatedCommodityService

        def overview_measure_ids
          @overview_measures.map(&:id)
        end

        def overview_measures
          @overview_measures.map { |measure| Api::V2::Headings::OverviewMeasurePresenter.new(measure, self) }
        end

        delegate :number_indents, to: :goods_nomenclature_indent, allow_nil: true

        delegate :description, to: :goods_nomenclature_description, allow_nil: true

        delegate :description_plain, to: :goods_nomenclature_description, allow_nil: true

        delegate :formatted_description, to: :goods_nomenclature_description, allow_nil: true

        def producline_suffix
          goods_nomenclature_indent.productline_suffix
        end
      end
    end
  end
end

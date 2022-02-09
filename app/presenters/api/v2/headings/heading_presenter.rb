module Api
  module V2
    module Headings
      class HeadingPresenter < SimpleDelegator
        delegate :id, to: :section, prefix: true, allow_nil: true
        delegate :id, to: :chapter, prefix: true, allow_nil: true

        def self.build(heading)
          presented = new(heading)

          AnnotatedCommodityService.new(presented).call

          presented
        end

        def commodity_ids
          commodities.map(&:id)
        end

        def footnote_ids
          footnotes.map(&:id)
        end

        def chapter
          super ? Api::V2::Headings::ChapterPresenter.new(super) : nil
        end

        def commodities
          @commodities ||= begin
            eager_loaded_commodities = commodities_dataset.eager(
              :goods_nomenclature_indents,
              :goods_nomenclature_descriptions,
            )

            eager_loaded_commodities.map do |commodity|
              eager_loaded_overview_measures = commodity.overview_measures_dataset.eager(
                { measure_type: :measure_type_description },
                {
                  measure_components: [
                    { duty_expression: :duty_expression_description },
                  ],
                },
              )

              Api::V2::Headings::CommodityPresenter.new(commodity, eager_loaded_overview_measures)
            end
          end
        end
      end
    end
  end
end

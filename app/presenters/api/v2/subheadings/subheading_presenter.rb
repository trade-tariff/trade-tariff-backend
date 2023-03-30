module Api
  module V2
    module Subheadings
      class SubheadingPresenter < SimpleDelegator
        def footnote_ids
          footnotes.map(&:id)
        end

        def heading_id
          heading.goods_nomenclature_sid
        end

        def chapter_id
          chapter.goods_nomenclature_sid
        end

        def commodities
          @commodities ||= CommodityPresenter.wrap(ancestors + [self] + ns_descendants)
        end

        def commodity_ids
          commodities.map(&:goods_nomenclature_sid)
        end

        def ancestors
          @ancestors ||= ns_ancestors.select do |ancestor|
            ancestor.ns_number_indents.positive?
          end
        end

        def ancestor_ids
          ancestors.map(&:goods_nomenclature_sid)
        end

        def section
          SectionPresenter.new(super)
        end

        def chapter
          ChapterPresenter.new(super)
        end
      end
    end
  end
end

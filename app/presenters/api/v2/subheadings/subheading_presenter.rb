module Api
  module V2
    module Subheadings
      class SubheadingPresenter < SimpleDelegator
        delegate :id, to: :section, prefix: true

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
          @commodities ||= Headings::CommodityPresenter.wrap(ancestors + [self] + ns_descendants)
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
          Headings::SectionPresenter.new(chapter.section)
        end

        def chapter
          @chapter ||= \
            Headings::ChapterPresenter.new(ns_ancestors.find { |a| a.is_a? Chapter })
        end

        def heading
          @heading ||= ns_ancestors.find { |a| a.is_a? Heading }
        end

        def number_indents
          ns_number_indents
        end
      end
    end
  end
end

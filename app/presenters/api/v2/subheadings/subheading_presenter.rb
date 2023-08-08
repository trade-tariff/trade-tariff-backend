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
          @commodities ||= Headings::CommodityPresenter.wrap(ten_digit_ancestors + [self] + descendants)
        end

        def commodity_ids
          commodities.map(&:goods_nomenclature_sid)
        end

        def ten_digit_ancestors
          @ten_digit_ancestors ||= ancestors.select { |ancestor| ancestor.is_a? TenDigitGoodsNomenclature }
        end

        def ten_digit_ancestor_ids
          ten_digit_ancestors.map(&:goods_nomenclature_sid)
        end

        def section
          Headings::SectionPresenter.new(chapter.section)
        end

        def chapter
          @chapter ||= \
            Headings::ChapterPresenter.new(ancestors.find { |a| a.is_a? Chapter })
        end

        def heading
          @heading ||= ancestors.find { |a| a.is_a? Heading }
        end
      end
    end
  end
end

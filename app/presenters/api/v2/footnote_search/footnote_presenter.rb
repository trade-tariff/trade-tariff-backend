module Api
  module V2
    module FootnoteSearch
      class FootnotePresenter < WrapDelegator
        def self.wrap(footnotes, grouped_goods_nomenclatures)
          footnotes.map do |footnote|
            key = "#{footnote.footnote_type_id}#{footnote.footnote_id}"
            goods_nomenclatures = grouped_goods_nomenclatures[key] || []

            new(footnote, goods_nomenclatures)
          end
        end

        attr_reader :goods_nomenclatures

        def initialize(footnote, goods_nomenclatures)
          super(footnote)

          @footnote = footnote
          @goods_nomenclatures = goods_nomenclatures
        end

        def goods_nomenclature_ids
          goods_nomenclatures.map(&:goods_nomenclature_sid)
        end
      end
    end
  end
end

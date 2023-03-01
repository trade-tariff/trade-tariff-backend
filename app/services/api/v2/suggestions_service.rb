module Api
  module V2
    class SuggestionsService < ::BaseSuggestionsService
      protected

      def handle_chapter_record(chapter)
        Api::V2::SuggestionPresenter.new(chapter.goods_nomenclature_sid, chapter.short_code)
      end

      def handle_heading_record(heading)
        Api::V2::SuggestionPresenter.new(heading.goods_nomenclature_sid, heading.short_code)
      end

      def handle_commodity_record(commodity)
        Api::V2::SuggestionPresenter.new(commodity.goods_nomenclature_sid, commodity.goods_nomenclature_item_id)
      end

      def handle_search_reference_record(search_reference)
        Api::V2::SuggestionPresenter.new(search_reference.id, search_reference.title)
      end

      def handle_chemical_record(chemical)
        Api::V2::SuggestionPresenter.new(chemical.id, chemical.cas)
      end
    end
  end
end

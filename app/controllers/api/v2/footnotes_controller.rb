module Api
  module V2
    class FootnotesController < ApiController
      def search
        render json: serialized_footnotes
      end

      private

      def serialized_footnotes
        Api::V2::Footnotes::FootnoteSerializer.new(
          finder_service.call,
          include: [:goods_nomenclatures],
        ).serializable_hash
      end

      def finder_service
        @finder_service ||= FootnoteFinderService.new(type, code, description)
      end

      def type
        footnote_search_params[:type]
      end

      def code
        footnote_search_params[:code]
      end

      def description
        footnote_search_params[:description]
      end

      def footnote_search_params
        params.permit(:type, :code, :description)
      end
    end
  end
end

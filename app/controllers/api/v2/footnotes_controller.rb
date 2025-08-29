module Api
  module V2
    class FootnotesController < ApiController
      def search
        if search_validator.valid?
          render json: serialized_footnotes
        else
          render json: serialized_errors, status: :unprocessable_content
        end
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

      def search_validator
        @search_validator ||= SearchValidator.new(footnote_search_params)
      end

      def serialized_errors
        Api::Search::ErrorSerializationService.new(search_validator).call
      end
    end
  end
end

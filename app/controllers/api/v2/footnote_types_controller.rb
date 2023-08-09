module Api
  module V2
    class FootnoteTypesController < ApiController
      def index
        render json: Api::V2::Footnotes::FootnoteTypeSerializer.new(footnote_types, {}).serializable_hash
      end

      private

      def footnote_types
        FootnoteType.all
      end
    end
  end
end

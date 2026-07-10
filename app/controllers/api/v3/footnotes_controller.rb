module Api
  module V3
    class FootnotesController < BaseController
      def index
        footnotes = Footnote.actual
          .eager(:footnote_descriptions)
          .order(Sequel.asc(%i[footnote_type_id footnote_id]))
          .all
        render json: Api::V3::FootnoteSerializer.collection(footnotes)
      end
    end
  end
end

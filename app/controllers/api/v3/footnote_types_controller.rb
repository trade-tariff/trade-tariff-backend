module Api
  module V3
    class FootnoteTypesController < BaseController
      def index
        footnote_types = FootnoteType.actual
          .eager(:footnote_type_description)
          .order(Sequel.asc(:footnote_type_id))
          .all
        render json: Api::V3::FootnoteSerializer.type_collection(footnote_types)
      end
    end
  end
end

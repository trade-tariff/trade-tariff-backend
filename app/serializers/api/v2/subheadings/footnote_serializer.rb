module Api
  module V2
    module Subheadings
      class FootnoteSerializer
        include JSONAPI::Serializer

        set_type :footnote

        set_id :footnote_id

        attributes :code, :description, :formatted_description
      end
    end
  end
end

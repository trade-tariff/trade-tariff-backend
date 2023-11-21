module Api
  module Admin
    class FootnoteSerializer
      include JSONAPI::Serializer

      set_type :footnote

      set_id :code

      attributes :footnote_id, :footnote_type_id, :validity_start_date, :validity_end_date

      attribute :description, &:formatted_description
    end
  end
end

module Api
  module Admin
    module SearchReferences
      class SectionSerializer
        include JSONAPI::Serializer

        set_type :section

        set_id :id

        attributes :numeral, :title, :position
      end
    end
  end
end

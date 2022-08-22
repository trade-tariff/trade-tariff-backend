module Api
  module V2
    module RulesOfOrigin
      class OriginReferenceDocumentSerializer
        include JSONAPI::Serializer

        set_type :rules_of_origin_origin_reference_document

        set_id :id

        attributes :ord_title, :ord_version, :ord_date, :ord_original
      end
    end
  end
end

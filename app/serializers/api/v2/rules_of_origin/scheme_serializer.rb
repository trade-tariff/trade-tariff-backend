module Api
  module V2
    module RulesOfOrigin
      class SchemeSerializer
        include JSONAPI::Serializer

        set_type :rules_of_origin_scheme

        set_id :scheme_code

        attributes :scheme_code, :title, :countries, :unilateral

        has_many :links, serializer: Api::V2::RulesOfOrigin::LinkSerializer
        has_one :origin_reference_document, serializer: Api::V2::RulesOfOrigin::OriginReferenceDocumentSerializer
      end
    end
  end
end

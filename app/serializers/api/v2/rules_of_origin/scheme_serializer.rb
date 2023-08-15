module Api
  module V2
    module RulesOfOrigin
      class SchemeSerializer
        include JSONAPI::Serializer

        set_type :rules_of_origin_scheme

        set_id :scheme_code

        attributes :scheme_code,
                   :title,
                   :countries,
                   :unilateral,
                   :proof_intro,
                   :proof_codes,
                   :show_proofs_for_geographical_areas

        has_many :links, serializer: Api::V2::RulesOfOrigin::LinkSerializer
        has_many :proofs, serializer: Api::V2::RulesOfOrigin::ProofSerializer
        has_one :origin_reference_document, serializer: Api::V2::RulesOfOrigin::OriginReferenceDocumentSerializer
        has_many :rule_sets, serializer: Api::V2::RulesOfOrigin::V2::RuleSetSerializer
      end
    end
  end
end

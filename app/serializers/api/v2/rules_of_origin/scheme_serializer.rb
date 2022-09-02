module Api
  module V2
    module RulesOfOrigin
      class SchemeSerializer
        include JSONAPI::Serializer

        set_type :rules_of_origin_scheme

        set_id :scheme_code

        attributes :scheme_code, :title, :countries, :footnote, :unilateral,
                   :fta_intro, :introductory_notes, :cumulation_methods

        has_many :rules, serializer: Api::V2::RulesOfOrigin::RuleSerializer
        has_many :links, serializer: Api::V2::RulesOfOrigin::LinkSerializer
        has_many :proofs, serializer: Api::V2::RulesOfOrigin::ProofSerializer
        has_many :articles, serializer: Api::V2::RulesOfOrigin::ArticleSerializer
        has_many :rule_sets, serializer: Api::V2::RulesOfOrigin::V2::RuleSetSerializer
        has_one :origin_reference_document, serializer: Api::V2::RulesOfOrigin::OriginReferenceDocumentSerializer
      end
    end
  end
end

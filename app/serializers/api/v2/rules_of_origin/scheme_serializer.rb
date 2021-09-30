module Api
  module V2
    module RulesOfOrigin
      class SchemeSerializer
        include JSONAPI::Serializer

        set_type :rules_of_origin_scheme

        set_id :scheme_code

        attributes :scheme_code, :title, :countries, :footnote, :fta_intro,
                   :introductory_notes

        has_many :rules, serializer: Api::V2::RulesOfOrigin::RuleSerializer
        has_many :links, serializer: Api::V2::RulesOfOrigin::LinkSerializer
        has_many :proofs, serializer: Api::V2::RulesOfOrigin::ProofSerializer
      end
    end
  end
end

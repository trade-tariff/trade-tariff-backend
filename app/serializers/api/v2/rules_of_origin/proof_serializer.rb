module Api
  module V2
    module RulesOfOrigin
      class ProofSerializer
        include JSONAPI::Serializer

        set_type :rules_of_origin_proof

        attributes :summary, :subtext, :url
      end
    end
  end
end

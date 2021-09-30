module Api
  module V2
    module RulesOfOrigin
      class ProofSerializer
        include JSONAPI::Serializer

        set_type :rules_of_origin_proof

        set_id :id

        attributes :summary, :content
      end
    end
  end
end

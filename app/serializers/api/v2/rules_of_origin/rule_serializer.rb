module Api
  module V2
    module RulesOfOrigin
      class RuleSerializer
        include JSONAPI::Serializer

        set_type :rules_of_origin_rule

        set_id :id_rule

        attributes :id_rule, :heading, :description, :rule
      end
    end
  end
end

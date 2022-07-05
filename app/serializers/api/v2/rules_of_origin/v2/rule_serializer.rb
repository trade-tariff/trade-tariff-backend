module Api
  module V2
    module RulesOfOrigin
      module V2
        class RuleSerializer
          include JSONAPI::Serializer

          set_type :rules_of_origin_v2_rule

          attributes :rule, :original, :rule_class, :operator
        end
      end
    end
  end
end

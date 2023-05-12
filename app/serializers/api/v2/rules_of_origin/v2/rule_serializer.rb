module Api
  module V2
    module RulesOfOrigin
      module V2
        class RuleSerializer
          include JSONAPI::Serializer

          set_type :rules_of_origin_v2_rule

          attributes :rule, :rule_class, :operator, :footnotes
        end
      end
    end
  end
end

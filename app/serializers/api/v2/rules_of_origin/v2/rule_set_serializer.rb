module Api
  module V2
    module RulesOfOrigin
      module V2
        class RuleSetSerializer
          include JSONAPI::Serializer

          set_type :rules_of_origin_rule_set

          attributes :heading, :subdivision

          has_many :rules, serializer: Api::V2::RulesOfOrigin::V2::RuleSerializer
        end
      end
    end
  end
end

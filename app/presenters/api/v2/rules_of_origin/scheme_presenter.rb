module Api
  module V2
    module RulesOfOrigin
      class SchemePresenter < SimpleDelegator
        attr_reader :rules

        class << self
          def for_many(schemes, rules)
            schemes.map do |scheme|
              new scheme, rules[scheme.scheme_code]
            end
          end
        end

        def initialize(scheme, rules)
          super(scheme)
          @scheme = scheme
          @rules = rules || []
        end

        def rule_ids
          @rule_ids ||= rules.map(&:id_rule)
        end
      end
    end
  end
end

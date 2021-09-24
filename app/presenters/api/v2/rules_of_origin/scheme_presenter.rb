module Api
  module V2
    module RulesOfOrigin
      class SchemePresenter < SimpleDelegator
        attr_reader :rules, :links

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
          @links = Array.wrap(scheme_set&.links) + @scheme.links
        end

        def rule_ids
          @rule_ids ||= rules.map(&:id_rule)
        end

        def link_ids
          @link_ids ||= links.map(&:id)
        end
      end
    end
  end
end

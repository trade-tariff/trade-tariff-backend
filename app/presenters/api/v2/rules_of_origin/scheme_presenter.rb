module Api
  module V2
    module RulesOfOrigin
      class SchemePresenter < SimpleDelegator
        attr_reader :rules, :links, :rule_sets

        class << self
          def for_many(schemes, rules, rule_sets)
            schemes.map do |scheme|
              new scheme,
                  rules[scheme.scheme_code],
                  rule_sets[scheme.scheme_code]
            end
          end
        end

        def initialize(scheme, rules, rule_sets)
          super(scheme)
          @scheme = scheme
          @rules = rules || []
          @links = Array.wrap(scheme_set&.links) + @scheme.links
          @rule_sets = rule_sets
        end

        def rule_ids
          @rule_ids ||= rules.map(&:id_rule)
        end

        def link_ids
          @link_ids ||= links.map(&:id)
        end

        def proof_ids
          @proof_ids ||= proofs.map(&:id)
        end

        def article_ids
          @article_ids ||= articles.map(&:id)
        end

        def rule_set_ids
          @rule_set_ids ||= rule_sets.map(&:id)
        end

        def origin_reference_document_id
          @origin_reference_document = "origin_reference_document_id"
        end
      end
    end
  end
end

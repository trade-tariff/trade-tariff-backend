module TariffKnowledge
  class Edge < Sequel::Model(:tariff_knowledge_edges)
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :not_nil

    DERIVED_FROM = 'derived_from'.freeze
    HAS_FRAGMENT = 'has_fragment'.freeze
    APPLIES_TO = 'applies_to'.freeze
    REFERENCES = 'references'.freeze
    EXCLUDES = 'excludes'.freeze
    CLASSIFIES_AS = 'classifies_as'.freeze
    CLASSIFIES_ONLY_AS = 'classifies_only_as'.freeze
    CONSTRAINS = 'constrains'.freeze
    DEFINES_TERM = 'defines_term'.freeze
    SUBJECT_TO = 'subject_to'.freeze

    many_to_one :source_node,
                class: 'TariffKnowledge::Node',
                key: :source_node_id
    many_to_one :target_node,
                class: 'TariffKnowledge::Node',
                key: :target_node_id

    dataset_module do
      def by_target(node)
        where(target_node_id: node.id)
      end

      def by_relationship(type)
        where(relationship_type: type)
      end
    end

    def validate
      super
      validates_presence :source_node_id
      validates_presence :target_node_id
      validates_presence :relationship_type
    end
  end
end

module TariffKnowledge
  class Edge < Sequel::Model(:tariff_knowledge_edges)
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :not_nil

    CONTAINS = 'contains'.freeze
    APPLIES_TO = 'applies_to'.freeze
    REFERENCES = 'references'.freeze
    EXPANDS_TO = 'expands_to'.freeze
    SUMMARISES = 'summarises'.freeze
    FOR_DECLARABLE = 'for_declarable'.freeze
    DERIVED_FROM = 'derived_from'.freeze

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

module TariffKnowledge
  class StaleGraphPruner
    def self.call(expected_sources:)
      new(expected_sources).call
    end

    def initialize(expected_sources)
      @expected_sources = expected_sources
    end

    def call
      Node.db.transaction do
        remove_stale_note_sources
        remove_orphan_rules
        remove_generated_contexts
      end
    end

  private

    attr_reader :expected_sources

    def remove_stale_note_sources
      stale_sources = Node.where(node_type: Node::NOTE_SOURCE).exclude(key: expected_source_keys)
      stale_rule_ids = Edge.where(
        source_node_id: stale_sources.select(:id),
        relationship_type: Edge::HAS_FRAGMENT,
      ).select_map(:target_node_id)

      Edge.where(source_node_id: stale_rule_ids).delete if stale_rule_ids.any?
      Edge.where(target_node_id: stale_rule_ids).delete if stale_rule_ids.any?
      Node.where(id: stale_rule_ids).delete if stale_rule_ids.any?
      stale_sources.delete
    end

    def remove_orphan_rules
      Node.rules
          .exclude(id: Edge.where(relationship_type: Edge::HAS_FRAGMENT).select(:target_node_id))
          .delete
    end

    def remove_generated_contexts
      DeclarableContext.where(manually_edited: false).delete
    end

    def expected_source_keys
      @expected_source_keys ||= expected_sources.map { |source| "note_source:#{source.key}" }
    end
  end
end

module TariffKnowledge
  class CoverageAnalyzer
    Finding = Data.define(:severity, :code, :message, :count)
    Result = Data.define(
      :expected_source_count,
      :actual_source_count,
      :rule_count,
      :applies_to_edge_count,
      :context_count,
      :findings,
    ) do
      def ok?
        findings.none? { |finding| finding.severity == 'error' }
      end
    end

    NOTE_SOURCE_TYPES = %w[CustomsTariffChapterNote CustomsTariffSectionNote].freeze

    def self.call(expected_sources: SourceLoader.call)
      new(expected_sources).call
    end

    def initialize(expected_sources)
      @expected_sources = expected_sources
      @findings = []
    end

    def call
      add_finding('error', 'no_expected_sources', 'No approved actual customs tariff chapter or section notes are available', 0) if expected_sources.empty?
      check_source_nodes
      check_rule_nodes
      check_declarable_contexts

      Result.new(
        expected_source_count: expected_sources.size,
        actual_source_count: expected_source_nodes.count,
        rule_count: rule_nodes.count,
        applies_to_edge_count: applies_to_edges.count,
        context_count: DeclarableContext.count,
        findings: findings,
      )
    end

  private

    attr_reader :expected_sources, :findings

    def check_source_nodes
      missing = expected_source_keys - expected_source_nodes.map(:key)
      unexpected = Node.where(node_type: Node::NOTE_SOURCE).exclude(key: expected_source_keys).map(:key)
      non_customs = Node.where(node_type: Node::NOTE_SOURCE).exclude(source_type: NOTE_SOURCE_TYPES).map(:key)

      add_finding('error', 'missing_source_nodes', 'Approved actual customs tariff notes missing graph source nodes', missing.size) if missing.any?
      add_finding('error', 'unexpected_source_nodes', 'Graph contains note source nodes outside the approved actual customs tariff note set', unexpected.size) if unexpected.any?
      add_finding('error', 'non_customs_source_nodes', 'Graph contains non-customs tariff note source nodes', non_customs.size) if non_customs.any?

      source_ids_without_rules = expected_source_nodes
        .exclude(id: Edge.where(relationship_type: Edge::HAS_FRAGMENT).select(:source_node_id))
        .map(:id)
      add_finding('error', 'sources_without_rules', 'Graph note source nodes without extracted rule fragments', source_ids_without_rules.size) if source_ids_without_rules.any?
    end

    def check_rule_nodes
      rules_without_applies_to = rule_nodes
        .exclude(id: applies_to_edges.select(:source_node_id))
        .count
      rules_not_reviewable = rule_nodes.where(needs_review: false).count

      add_finding('error', 'rules_without_applies_to', 'Extracted rules without declarable applies_to edges', rules_without_applies_to) if rules_without_applies_to.positive?
      add_finding('error', 'rules_not_reviewable', 'Extracted rules not marked for review', rules_not_reviewable) if rules_not_reviewable.positive?
    end

    def check_declarable_contexts
      target_sids = Node.goods_nomenclatures
                       .where(id: applies_to_edges.select(:target_node_id))
                       .select_map(:goods_nomenclature_sid)
      missing_contexts = target_sids - DeclarableContext.by_sids(target_sids).select_map(:goods_nomenclature_sid)
      contexts_not_reviewable = DeclarableContext.by_sids(target_sids).where(needs_review: false).count

      add_finding('error', 'missing_declarable_contexts', 'Declarables with connected note rules missing compressed contexts', missing_contexts.size) if missing_contexts.any?
      add_finding('error', 'contexts_not_reviewable', 'Compressed declarable contexts not marked for review', contexts_not_reviewable) if contexts_not_reviewable.positive?
    end

    def expected_source_nodes
      @expected_source_nodes ||= Node.where(node_type: Node::NOTE_SOURCE, key: expected_source_keys)
    end

    def rule_nodes
      @rule_nodes ||= Node.rules
    end

    def applies_to_edges
      @applies_to_edges ||= Edge.where(relationship_type: Edge::APPLIES_TO)
    end

    def expected_source_keys
      @expected_source_keys ||= expected_sources.map { |source| "note_source:#{source.key}" }
    end

    def add_finding(severity, code, message, count)
      findings << Finding.new(severity:, code:, message:, count:)
    end
  end
end

module TariffKnowledge
  class SemanticRuleFactExtraction
    Result = Data.define(:fragment_count, :fact_count, :goods_nomenclature_count)

    def self.call(fragment_node_ids: nil)
      new(fragment_node_ids).call
    end

    def initialize(fragment_node_ids)
      @fragment_node_ids = fragment_node_ids
    end

    def call
      fragment_count = 0
      fact_count = 0
      processed_fragment_node_ids = []

      referenced_fragments.each do |fragment_node, source_reference, candidate_references|
        facts = SemanticRuleFactExtractor.call(fragment_node:, source_reference:, candidate_references:)
        fragment_count += 1
        fact_count += facts.size
        processed_fragment_node_ids << fragment_node.id
      end

      affected_goods_nomenclature_sids = affected_goods_nomenclature_sids(processed_fragment_node_ids)
      CompressedNoteGenerator.call(goods_nomenclature_sids: affected_goods_nomenclature_sids) if affected_goods_nomenclature_sids.any?

      Result.new(
        fragment_count:,
        fact_count:,
        goods_nomenclature_count: affected_goods_nomenclature_sids.size,
      )
    end

  private

    attr_reader :fragment_node_ids

    def referenced_fragments
      references_by_fragment_id.filter_map do |fragment_node_id, references|
        fragment_node = fragment_nodes_by_id[fragment_node_id]
        next unless fragment_node && references.any?

        [fragment_node, source_reference_for(fragment_node), references]
      end
    end

    def source_reference_for(fragment_node)
      case fragment_node.source_type
      when 'customs_tariff_section_note'
        { 'type' => 'section', 'code' => fragment_node.source_id }
      when 'customs_tariff_chapter_note'
        { 'type' => 'chapter', 'code' => fragment_node.source_id }
      when 'customs_tariff_general_rule'
        { 'type' => 'rule', 'code' => fragment_node.source_id }
      end
    end

    def references_by_fragment_id
      @references_by_fragment_id ||= reference_edges.each_with_object({}) do |edge, grouped|
        range_node = range_nodes_by_id[edge.target_node_id]
        next unless range_node

        range_metadata = range_node.metadata.to_h
        grouped[edge.source_node_id] ||= []
        grouped[edge.source_node_id] << {
          'type' => range_metadata['range_type'],
          'code' => range_metadata['code'],
        }
      end
    end

    def reference_edges
      dataset = Edge.by_relationship(Edge::REFERENCES)
      dataset = dataset.where(source_node_id: fragment_node_ids) if fragment_node_ids.present?
      dataset.all
    end

    def fragment_nodes_by_id
      @fragment_nodes_by_id ||= begin
        dataset = Node.note_fragments.where(id: references_source_node_ids)
        dataset = dataset.where(source_version: current_source_version) if current_source_version.present?
        dataset.all.index_by(&:id)
      end
    end

    def range_nodes_by_id
      @range_nodes_by_id ||= Node
        .where(node_type: Node::RANGE, id: reference_edges.map(&:target_node_id).uniq)
        .all
        .index_by(&:id)
    end

    def references_source_node_ids
      reference_edges.map(&:source_node_id).uniq
    end

    def affected_goods_nomenclature_sids(fragment_node_ids)
      return [] if fragment_node_ids.empty?

      direct_sids = Edge
        .by_relationship(Edge::APPLIES_TO)
        .where(source_node_id: fragment_node_ids)
        .association_join(:target_node)
        .exclude(target_node__goods_nomenclature_sid: nil)
        .select_map(Sequel[:target_node][:goods_nomenclature_sid])

      range_node_ids = Edge
        .by_relationship(Edge::REFERENCES)
        .where(source_node_id: fragment_node_ids)
        .select_map(:target_node_id)

      expanded_sids = Edge
        .by_relationship(Edge::EXPANDS_TO)
        .where(source_node_id: range_node_ids)
        .association_join(:target_node)
        .exclude(target_node__goods_nomenclature_sid: nil)
        .select_map(Sequel[:target_node][:goods_nomenclature_sid])

      (direct_sids + expanded_sids)
        .compact
        .uniq
        .sort
    end

    def current_source_version
      return @current_source_version if defined?(@current_source_version)

      @current_source_version = TimeMachine.at(@time_machine_date ||= Time.current) do
        CustomsTariffUpdate
          .actual
          .exclude(status: SourceGraphLoader::EXCLUDED_UPDATE_STATUSES)
          .order(Sequel.desc(:validity_start_date))
          .get(:version)
      end
    end
  end
end

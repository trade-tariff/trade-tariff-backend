module TariffKnowledge
  class CompressedNoteGenerator
    def self.call(goods_nomenclature_sids:)
      new(goods_nomenclature_sids).call
    end

    def initialize(goods_nomenclature_sids)
      @goods_nomenclature_sids = goods_nomenclature_sids
    end

    def call
      declarable_nodes.filter_map do |declarable_node|
        generate_for(declarable_node)
      end
    end

  private

    attr_reader :goods_nomenclature_sids

    def declarable_nodes
      Node.goods_nomenclatures
          .where(goods_nomenclature_sid: goods_nomenclature_sids)
          .all
    end

    def generate_for(declarable_node)
      evidence = evidence_for(declarable_node)
      return if evidence.empty?

      content = content_for(evidence)
      attributes = {
        goods_nomenclature_item_id: declarable_node.goods_nomenclature_item_id,
        producline_suffix: declarable_node.producline_suffix,
        goods_nomenclature_type: declarable_node.goods_nomenclature_type,
        content:,
        metadata: Sequel.pg_jsonb(metadata_for(evidence)),
        context_hash: Digest::SHA256.hexdigest(content),
        generated_at: Time.zone.now,
        needs_review: true,
        approved: false,
        manually_edited: false,
        stale: false,
        expired: false,
      }

      upsert_note(declarable_node, attributes)
    end

    def evidence_for(declarable_node)
      range_nodes = range_nodes_for(declarable_node)
      indexed_range_nodes = range_nodes_by_id(range_nodes)
      evidence = fragment_nodes_by_range_node_id(range_nodes).flat_map do |range_node_id, fragment_nodes|
        range_node = indexed_range_nodes[range_node_id]
        fragment_nodes.map { |fragment_node| [fragment_node, range_node] }
      end

      evidence.sort_by { |fragment_node, range_node| [fragment_node.source_type.to_s, fragment_node.source_id.to_s, fragment_node.key, range_node.key] }
    end

    def range_nodes_for(declarable_node)
      range_node_ids = Edge
        .by_relationship(Edge::EXPANDS_TO)
        .where(target_node_id: declarable_node.id)
        .select_map(:source_node_id)
      return [] if range_node_ids.empty?

      Node.where(id: range_node_ids, node_type: Node::RANGE).all
    end

    def fragment_nodes_by_range_node_id(range_nodes)
      range_node_ids = range_nodes.map(&:id)
      return {} if range_node_ids.empty?

      reference_edges = Edge
        .by_relationship(Edge::REFERENCES)
        .where(target_node_id: range_node_ids)
        .all
      fragment_nodes = Node
        .note_fragments
        .where(id: reference_edges.map(&:source_node_id).uniq)
        .all
        .index_by(&:id)

      reference_edges.each_with_object({}) do |edge, grouped|
        fragment_node = fragment_nodes[edge.source_node_id]
        next unless fragment_node

        grouped[edge.target_node_id] ||= []
        grouped[edge.target_node_id] << fragment_node
      end
    end

    def range_nodes_by_id(range_nodes)
      range_nodes.index_by(&:id)
    end

    def content_for(evidence)
      evidence.map { |fragment_node, _range_node|
        "#{fragment_node.title}\n#{fragment_node.content}"
      }.uniq.join("\n\n")
    end

    def metadata_for(evidence)
      {
        'source_node_keys' => evidence.map { |fragment_node, _range_node| fragment_node.key }.uniq,
        'range_node_keys' => evidence.map { |_fragment_node, range_node| range_node.key }.uniq,
      }
    end

    def upsert_note(declarable_node, attributes)
      note = CompressedNote[declarable_node.goods_nomenclature_sid]
      return note if note&.manually_edited

      if note
        note.update(attributes)
      else
        CompressedNote.create(attributes.merge(goods_nomenclature_sid: declarable_node.goods_nomenclature_sid))
      end
    end
  end
end

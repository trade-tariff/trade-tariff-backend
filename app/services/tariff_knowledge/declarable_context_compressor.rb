module TariffKnowledge
  class DeclarableContextCompressor
    def self.call(goods_nomenclature_sids:)
      new(goods_nomenclature_sids).call
    end

    def initialize(goods_nomenclature_sids)
      @goods_nomenclature_sids = goods_nomenclature_sids
    end

    def call
      declarable_nodes = Node.goods_nomenclatures
                              .where(goods_nomenclature_sid: goods_nomenclature_sids)
                              .all
      edges_by_target_node_id = applies_to_edges_by_target_node_id(declarable_nodes)
      rule_nodes_by_id = rule_nodes_by_id(edges_by_target_node_id.values.flatten)

      declarable_nodes.filter_map do |declarable_node|
        rule_nodes = edges_by_target_node_id.fetch(declarable_node.id, []).filter_map do |edge|
          rule_nodes_by_id[edge.source_node_id]
        end
        compress(declarable_node, rule_nodes)
      end
    end

  private

    attr_reader :goods_nomenclature_sids

    def compress(declarable_node, rule_nodes)
      return if rule_nodes.empty?

      content = content_for(sort_rule_nodes(rule_nodes))
      context_hash = Digest::SHA256.hexdigest(content)
      attributes = {
        goods_nomenclature_item_id: declarable_node.goods_nomenclature_item_id,
        content: content,
        metadata: Sequel.pg_jsonb_wrap('rule_node_ids' => rule_nodes.map(&:id)),
        context_hash: context_hash,
        generated_at: Time.zone.now,
        needs_review: true,
        approved: false,
      }

      goods_nomenclature_sid = declarable_node.goods_nomenclature_sid
      context = DeclarableContext[goods_nomenclature_sid]
      if context
        return context if context.manually_edited

        context.update(attributes.merge(stale: false))
        context
      else
        DeclarableContext.create(attributes.merge(goods_nomenclature_sid:))
      end
    end

    def applies_to_edges_by_target_node_id(declarable_nodes)
      target_node_ids = declarable_nodes.map(&:id)
      return {} if target_node_ids.empty?

      Edge.where(target_node_id: target_node_ids, relationship_type: Edge::APPLIES_TO)
          .all
          .group_by(&:target_node_id)
    end

    def rule_nodes_by_id(edges)
      source_node_ids = edges.map(&:source_node_id).uniq
      return {} if source_node_ids.empty?

      Node.rules.where(id: source_node_ids).all.index_by(&:id)
    end

    def sort_rule_nodes(rule_nodes)
      rule_nodes.sort_by do |rule_node|
        [rule_node.source_type.to_s, rule_node.source_id.to_s, rule_node.key.to_s]
      end
    end

    def content_for(rule_nodes)
      rule_nodes.map { |rule_node|
        metadata = json_hash(rule_node.metadata)
        rule_type = metadata['rule_type'].to_s.humanize.downcase

        "#{rule_node.title}: #{rule_type}. #{rule_node.content}"
      }.join("\n")
    end

    def json_hash(value)
      case value
      when Sequel::Postgres::JSONBHash then value.to_hash
      when Hash then value
      else {}
      end
    end
  end
end

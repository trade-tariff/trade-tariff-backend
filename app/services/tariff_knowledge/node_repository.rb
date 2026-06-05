module TariffKnowledge
  class NodeRepository
    def self.upsert_node(attributes)
      new.upsert_node(attributes)
    end

    def self.upsert_edge(source_node, target_node, relationship_type, metadata = {})
      new.upsert_edge(source_node, target_node, relationship_type, metadata)
    end

    def self.bulk_upsert_edges(source_node, target_nodes, relationship_type, metadata = {})
      new.bulk_upsert_edges(source_node, target_nodes, relationship_type, metadata)
    end

    def self.upsert_goods_nomenclature(goods_nomenclature)
      new.upsert_goods_nomenclature(goods_nomenclature)
    end

    def self.bulk_upsert_goods_nomenclatures(goods_nomenclatures)
      new.bulk_upsert_goods_nomenclatures(goods_nomenclatures)
    end

    def bulk_upsert_goods_nomenclatures(goods_nomenclatures)
      rows = goods_nomenclatures.map { |goods_nomenclature| goods_nomenclature_row(goods_nomenclature) }
      return if rows.empty?

      Node.dataset
          .insert_conflict(target: :key, update: goods_nomenclature_update_values)
          .multi_insert(rows)
    end

    def upsert_goods_nomenclature(goods_nomenclature)
      upsert_node(goods_nomenclature_row(goods_nomenclature).except(:created_at, :updated_at))
    end

    def upsert_node(attributes)
      attributes = attributes.merge(metadata: jsonb(attributes.fetch(:metadata, {})))
      node = Node.by_key(attributes[:key]).first

      if node
        return node if node.manually_edited

        node.update(attributes.merge(stale: false))
        node
      else
        Node.create(attributes)
      end
    end

    def upsert_edge(source_node, target_node, relationship_type, metadata = {})
      bulk_upsert_edges(source_node, [target_node], relationship_type, metadata)
    end

    def bulk_upsert_edges(source_node, target_nodes, relationship_type, metadata = {})
      target_nodes.each_slice(1_000) do |batch|
        rows = edge_rows(source_node, batch, relationship_type, metadata)
        next if rows.empty?

        Edge.dataset
            .insert_conflict(target: %i[source_node_id target_node_id relationship_type], update: edge_update_values)
            .multi_insert(rows)
      end
    end

  private

    def goods_nomenclature_row(goods_nomenclature)
      now = Time.zone.now

      {
        key: "goods_nomenclature:#{goods_nomenclature.goods_nomenclature_sid}",
        node_type: Node::GOODS_NOMENCLATURE,
        title: goods_nomenclature.goods_nomenclature_item_id,
        content: goods_nomenclature.description,
        metadata: Sequel.pg_jsonb({}),
        goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
        goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
        producline_suffix: goods_nomenclature.producline_suffix,
        goods_nomenclature_type: goods_nomenclature.goods_nomenclature_class,
        validity_start_date: goods_nomenclature.validity_start_date,
        validity_end_date: goods_nomenclature.validity_end_date,
        created_at: now,
        updated_at: now,
      }
    end

    def goods_nomenclature_update_values
      {
        title: Sequel[:excluded][:title],
        content: Sequel[:excluded][:content],
        goods_nomenclature_sid: Sequel[:excluded][:goods_nomenclature_sid],
        goods_nomenclature_item_id: Sequel[:excluded][:goods_nomenclature_item_id],
        producline_suffix: Sequel[:excluded][:producline_suffix],
        goods_nomenclature_type: Sequel[:excluded][:goods_nomenclature_type],
        validity_start_date: Sequel[:excluded][:validity_start_date],
        validity_end_date: Sequel[:excluded][:validity_end_date],
        stale: false,
        updated_at: Sequel[:excluded][:updated_at],
      }
    end

    def edge_rows(source_node, target_nodes, relationship_type, metadata)
      now = Time.zone.now

      target_nodes.map do |target_node|
        {
          source_node_id: source_node.id,
          target_node_id: target_node.id,
          relationship_type: relationship_type,
          metadata: jsonb(metadata),
          validity_start_date: source_node.validity_start_date,
          validity_end_date: source_node.validity_end_date,
          created_at: now,
          updated_at: now,
        }
      end
    end

    def edge_update_values
      {
        metadata: Sequel[:excluded][:metadata],
        validity_start_date: Sequel[:excluded][:validity_start_date],
        validity_end_date: Sequel[:excluded][:validity_end_date],
        updated_at: Sequel[:excluded][:updated_at],
      }
    end

    def jsonb(value)
      case value
      when Sequel::Postgres::JSONBHash then value
      when Hash
        value.empty? ? Sequel.pg_jsonb({}) : Sequel.pg_jsonb_wrap(value)
      else Sequel.pg_jsonb_wrap(value)
      end
    end
  end
end

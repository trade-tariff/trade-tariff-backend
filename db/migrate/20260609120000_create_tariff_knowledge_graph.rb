Sequel.migration do
  up do
    create_table :tariff_knowledge_nodes do
      primary_key :id

      String :node_type, null: false
      String :key, null: false
      String :title, text: true
      String :content, text: true
      Jsonb :metadata, null: false, default: Sequel.lit("'{}'::jsonb")

      Integer :goods_nomenclature_sid
      String :goods_nomenclature_item_id, size: 10
      String :producline_suffix, size: 2
      String :goods_nomenclature_type, size: 50
      Integer :section_id

      String :source_type
      String :source_id
      String :source_version

      Date :validity_start_date
      Date :validity_end_date
      DateTime :generated_at
      DateTime :created_at, null: false
      DateTime :updated_at, null: false

      index :node_type
      index :key, unique: true
      index :goods_nomenclature_sid
      index :goods_nomenclature_item_id
      index :section_id
      index %i[source_type source_id source_version]
      index :metadata, type: :gin
    end

    create_table :tariff_knowledge_edges do
      primary_key :id

      foreign_key :source_node_id, :tariff_knowledge_nodes, null: false, on_delete: :cascade
      foreign_key :target_node_id, :tariff_knowledge_nodes, null: false, on_delete: :cascade
      String :relationship_type, null: false
      Jsonb :metadata, null: false, default: Sequel.lit("'{}'::jsonb")

      Date :validity_start_date
      Date :validity_end_date
      DateTime :created_at, null: false
      DateTime :updated_at, null: false

      index :source_node_id
      index :target_node_id
      index :relationship_type
      index %i[target_node_id relationship_type]
      index %i[source_node_id target_node_id relationship_type], unique: true, name: :idx_tariff_knowledge_edges_unique
      index :metadata, type: :gin
    end

    create_table :tariff_knowledge_compressed_notes do
      Integer :goods_nomenclature_sid, primary_key: true
      String :goods_nomenclature_item_id, size: 10, null: false
      String :producline_suffix, size: 2, null: false
      String :goods_nomenclature_type, size: 50, null: false
      String :content, text: true, null: false
      Jsonb :metadata, null: false, default: Sequel.lit("'{}'::jsonb")
      String :context_hash, size: 64, null: false

      TrueClass :needs_review, null: false, default: false
      TrueClass :approved, null: false, default: false
      TrueClass :manually_edited, null: false, default: false
      TrueClass :stale, null: false, default: false
      TrueClass :expired, null: false, default: false

      DateTime :generated_at, null: false
      DateTime :created_at, null: false
      DateTime :updated_at, null: false

      index :goods_nomenclature_item_id
      index :needs_review, where: Sequel.lit('needs_review = TRUE')
      index :approved, where: Sequel.lit('approved = TRUE')
      index :expired, where: Sequel.lit('expired = TRUE')
    end
  end

  down do
    drop_table :tariff_knowledge_compressed_notes
    drop_table :tariff_knowledge_edges
    drop_table :tariff_knowledge_nodes
  end
end

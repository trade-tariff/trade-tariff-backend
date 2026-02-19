Sequel.migration do
  up do
    alter_table :goods_nomenclature_self_texts do
      add_column :search_embedding, 'vector(1536)'
      add_column :search_text, :text
    end

    run <<~SQL
      CREATE INDEX goods_nomenclature_self_texts_search_embedding_index
        ON goods_nomenclature_self_texts
        USING hnsw (search_embedding vector_cosine_ops)
        WITH (m = 16, ef_construction = 64)
    SQL
  end

  down do
    run 'DROP INDEX IF EXISTS goods_nomenclature_self_texts_search_embedding_index'

    alter_table :goods_nomenclature_self_texts do
      drop_column :search_text
      drop_column :search_embedding
    end
  end
end

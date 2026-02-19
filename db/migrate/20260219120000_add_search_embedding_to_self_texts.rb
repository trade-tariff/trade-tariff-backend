Sequel.migration do
  up do
    alter_table :goods_nomenclature_self_texts do
      # Composite embedding for vector retrieval (OpenAI text-embedding-3-small, 1536 dims)
      add_column :search_embedding, 'vector(1536)'
      # Pre-embedding composite text stored for debugging/audit
      add_column :search_text, :text
    end

    # HNSW (Hierarchical Navigable Small World) is an approximate nearest neighbour
    # index provided by pgvector. It builds a multi-layer graph where each node
    # connects to its closest neighbours. At query time, the graph is traversed
    # from a random entry point, greedily moving to closer neighbours at each hop.
    #
    # vector_cosine_ops: index uses cosine distance (<=> operator)
    # m = 16:              max connections per node per layer (higher = better recall, more memory)
    # ef_construction = 64: search width during index build (higher = better index quality, slower build)
    #
    # At query time, hnsw.ef_search (SET LOCAL per query) controls recall vs speed.
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

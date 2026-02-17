Sequel.migration do
  up do
    run 'CREATE EXTENSION IF NOT EXISTS vector'

    alter_table :goods_nomenclature_self_texts do
      add_column :embedding, 'vector(1536)'
      add_column :eu_self_text, :text
      add_column :eu_embedding, 'vector(1536)'
      add_column :similarity_score, Float
      add_column :coherence_score, Float
    end
  end

  down do
    alter_table :goods_nomenclature_self_texts do
      drop_column :coherence_score
      drop_column :similarity_score
      drop_column :eu_embedding
      drop_column :eu_self_text
      drop_column :embedding
    end
  end
end

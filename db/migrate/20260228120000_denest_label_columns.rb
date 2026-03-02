Sequel.migration do
  up do
    alter_table :goods_nomenclature_labels do
      add_column :description, :text
      add_column :original_description, :text
      add_column :synonyms, 'text[]', default: Sequel.lit("'{}'")
      add_column :colloquial_terms, 'text[]', default: Sequel.lit("'{}'")
      add_column :known_brands, 'text[]', default: Sequel.lit("'{}'")
      add_column :description_score, Float
      add_column :synonym_scores, 'float[]', default: Sequel.lit("'{}'")
      add_column :colloquial_term_scores, 'float[]', default: Sequel.lit("'{}'")
    end

    if TradeTariffBackend.uk?
      run <<~SQL
        UPDATE goods_nomenclature_labels SET
          description = labels->>'description',
          original_description = labels->>'original_description',
          synonyms = ARRAY(SELECT jsonb_array_elements_text(COALESCE(labels->'synonyms', '[]'))),
          colloquial_terms = ARRAY(SELECT jsonb_array_elements_text(COALESCE(labels->'colloquial_terms', '[]'))),
          known_brands = ARRAY(SELECT jsonb_array_elements_text(COALESCE(labels->'known_brands', '[]')))
        WHERE labels != '{}'::jsonb
      SQL
    end
  end

  down do
    alter_table :goods_nomenclature_labels do
      drop_column :colloquial_term_scores
      drop_column :synonym_scores
      drop_column :description_score
      drop_column :known_brands
      drop_column :colloquial_terms
      drop_column :synonyms
      drop_column :original_description
      drop_column :description
    end
  end
end

Sequel.migration do
  up do
    create_table :tariff_knowledge_synthetic_atars do
      primary_key :id

      String :chapter, size: 2, null: false
      String :real_user_search, text: true, null: false
      Integer :times_searched
      String :likely_heading
      String :description, text: true, null: false
      String :goods_nomenclature_item_id, size: 10, null: false
      String :notes, text: true
      String :completed_by

      DateTime :created_at, null: false
      DateTime :updated_at, null: false

      index :chapter, name: :synthetic_atars_chapter_index
      index :goods_nomenclature_item_id, name: :synthetic_atars_item_id_index
    end

    alter_table :tariff_knowledge_synthetic_atars do
      add_constraint :synthetic_atars_chapter_format, Sequel.lit("chapter ~ '^[0-9]{2}$'")
      add_constraint :synthetic_atars_item_id_format, Sequel.lit("goods_nomenclature_item_id ~ '^[0-9]{10}$'")
    end

    # A synthetic ATaR is identified by its real user search, compared without
    # regard to case. The index name stays under Postgres's 63 character limit.
    run <<~SQL
      CREATE UNIQUE INDEX tariff_knowledge_synthetic_atars_real_user_search_lower_index
      ON tariff_knowledge_synthetic_atars (lower(real_user_search))
    SQL
  end

  down do
    drop_table :tariff_knowledge_synthetic_atars
  end
end

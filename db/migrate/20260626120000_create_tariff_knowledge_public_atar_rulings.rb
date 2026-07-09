Sequel.migration do
  up do
    create_table :tariff_knowledge_public_atar_rulings do
      primary_key :id

      String :ref, null: false
      String :commodity_code, null: false
      String :goods_nomenclature_item_id, size: 10, null: false
      String :description, text: true, null: false
      column :keywords, 'text[]', null: false, default: Sequel.pg_array([], :text)
      String :justification, text: true, null: false
      Date :validity_start_date, null: false
      Date :validity_end_date, null: false
      String :source_url, text: true, null: false
      Jsonb :raw_fields, null: false, default: Sequel.lit("'{}'::jsonb")

      DateTime :first_seen_at, null: false
      DateTime :last_seen_at, null: false
      DateTime :fetched_at, null: false
      DateTime :created_at, null: false
      DateTime :updated_at, null: false

      index :ref, unique: true
      index :commodity_code
      index :goods_nomenclature_item_id
      index :validity_start_date
      index :validity_end_date
      index :keywords, type: :gin
      index :raw_fields, type: :gin
    end

    alter_table :tariff_knowledge_public_atar_rulings do
      add_constraint :tariff_knowledge_public_atars_commodity_code_format, Sequel.lit("commodity_code ~ '^[0-9]{6}([0-9]{2}){0,2}$'")
      add_constraint :tariff_knowledge_public_atars_goods_nomenclature_item_id_format, Sequel.lit("goods_nomenclature_item_id ~ '^[0-9]{10}$'")
      add_constraint :tariff_knowledge_public_atars_normalized_goods_nomenclature_item_id, Sequel.lit("goods_nomenclature_item_id = rpad(commodity_code, 10, '0')")
    end
  end

  down do
    drop_table :tariff_knowledge_public_atar_rulings
  end
end

Sequel.migration do
  up do
    alter_table :tariff_knowledge_public_atar_rulings do
      add_column :derived_facts, 'text[]', null: false, default: Sequel.pg_array([], :text)

      add_index :derived_facts, type: :gin
    end
  end

  down do
    alter_table :tariff_knowledge_public_atar_rulings do
      drop_column :derived_facts
    end
  end
end

# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table :search_references do
      add_index :goods_nomenclature_sid
    end
  end

  down do
    alter_table :search_references do
      drop_index :goods_nomenclature_sid
    end
  end
end

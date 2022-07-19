# frozen_string_literal: true

Sequel.migration do
  change do
    create_table :guides_goods_nomenclatures do
      primary_key :id

      integer :guide_id, index: true, null: false
      integer :goods_nomenclature_sid, index: true, null: false
    end
  end
end

# frozen_string_literal: true

Sequel.migration do
  change do
    create_table :tariff_changes do
      primary_key :id
      String :type, null: false
      Integer :object_sid, null: false
      Integer :goods_nomenclature_sid, null: false
      String :goods_nomenclature_item_id, size: 10, null: false
      String :action, null: false
      Date :operation_date, null: false
      Date :date_of_effect, null: false
      DateTime :validity_start_date
      DateTime :validity_end_date
      DateTime :updated_at
      DateTime :created_at

      index :goods_nomenclature_item_id
    end
  end
end

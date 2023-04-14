Sequel.migration do
  up do
    create_table :full_chemicals do
      String :cus, null: false
      Integer :goods_nomenclature_sid
      String :cn_code
      String :cas_rn
      String :ec_number
      String :un_number
      String :nomen
      String :name
      String :goods_nomenclature_item_id
      String :producline_suffix
      DateTime :updated_at
      DateTime :created_at

      primary_key %i[cus goods_nomenclature_sid]
    end

    add_index :full_chemicals, :cus, name: 'full_chemicals_cus_idx'
    add_index :full_chemicals, :cas_rn, name: 'full_chemicals_cas_rn_idx'
    add_index :full_chemicals, %i[goods_nomenclature_item_id producline_suffix], name: 'full_chemicals_goods_nomenclature_item_id_producline_suffix_idx'
    add_index :full_chemicals, :goods_nomenclature_sid, name: 'full_chemicals_goods_nomenclature_sid_idx'
  end

  down do
    drop_index :full_chemicals, :cus, name: 'full_chemicals_cus_idx'
    drop_index :full_chemicals, :cas_rn, name: 'full_chemicals_cas_rn_idx'
    drop_index :full_chemicals, %i[goods_nomenclature_item_id producline_suffix], name: 'full_chemicals_goods_nomenclature_item_id_producline_suffix_idx'
    drop_index :full_chemicals, :goods_nomenclature_sid, name: 'full_chemicals_goods_nomenclature_sid_idx'

    drop_table :full_chemicals
  end
end

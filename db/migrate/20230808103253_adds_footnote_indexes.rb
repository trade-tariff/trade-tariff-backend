Sequel.migration do
  up do
    add_index :measures_oplog, :measure_generating_regulation_role
    add_index :measures_oplog, :validity_start_date
    add_index :measures_oplog, :validity_end_date

    add_index :base_regulations_oplog, :approved_flag
    add_index :base_regulations_oplog, :validity_start_date
    add_index :base_regulations_oplog, :effective_end_date
    add_index :base_regulations_oplog, :validity_end_date

    add_index :modification_regulations_oplog, :approved_flag
    add_index :modification_regulations_oplog, :validity_start_date
    add_index :modification_regulations_oplog, :effective_end_date
    add_index :modification_regulations_oplog, :validity_end_date

    add_index :footnote_association_measures_oplog, :footnote_type_id

    add_index :footnote_association_goods_nomenclatures_oplog, :footnote_id
    add_index :footnote_association_goods_nomenclatures_oplog, :footnote_type
    add_index :footnote_association_goods_nomenclatures_oplog, :goods_nomenclature_sid

    add_index :goods_nomenclatures_oplog, :validity_start_date
    add_index :goods_nomenclatures_oplog, :validity_end_date

    run 'CREATE INDEX footnote_descriptions_description_trgm_idx ON footnote_descriptions_oplog USING GIST (description gist_trgm_ops);'
  end

  down do
    drop_index :measures_oplog, :measure_generating_regulation_role
    drop_index :measures_oplog, :validity_start_date
    drop_index :measures_oplog, :validity_end_date

    drop_index :base_regulations_oplog, :approved_flag
    drop_index :base_regulations_oplog, :validity_start_date
    drop_index :base_regulations_oplog, :effective_end_date
    drop_index :base_regulations_oplog, :validity_end_date

    drop_index :modification_regulations_oplog, :approved_flag
    drop_index :modification_regulations_oplog, :validity_start_date
    drop_index :modification_regulations_oplog, :effective_end_date
    drop_index :modification_regulations_oplog, :validity_end_date

    drop_index :footnote_association_measures_oplog, :footnote_type_id

    drop_index :footnote_association_goods_nomenclatures_oplog, :footnote_id
    drop_index :footnote_association_goods_nomenclatures_oplog, :footnote_type
    drop_index :footnote_association_goods_nomenclatures_oplog, :goods_nomenclature_sid

    drop_index :goods_nomenclatures_oplog, :validity_start_date
    drop_index :goods_nomenclatures_oplog, :validity_end_date

    run 'DROP INDEX footnote_descriptions_description_trgm_idx;'
  end
end

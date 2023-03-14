Sequel.migration do
  up do
    create_view :goods_nomenclature_tree_nodes, <<~EOVIEW, materialized: true
      SELECT
        indents.goods_nomenclature_indent_sid,
        indents.goods_nomenclature_sid,
        indents.number_indents,
        indents.goods_nomenclature_item_id,
        indents.productline_suffix,
        CONCAT(indents.goods_nomenclature_item_id, indents.productline_suffix)::bigint AS "position",
        indents.validity_start_date,
        COALESCE(indents.validity_end_date, MIN(replacement_indents.validity_start_date) - INTERVAL '1 second', nomenclatures.validity_end_date) as validity_end_date,
        indents.oid,
        indents.number_indents + 2 - (indents.goods_nomenclature_item_id LIKE '%00000000' AND indents.number_indents = 0)::integer AS "depth"
      FROM public.goods_nomenclature_indents indents
      INNER JOIN goods_nomenclatures nomenclatures ON
        indents.goods_nomenclature_sid = nomenclatures.goods_nomenclature_sid
      LEFT JOIN goods_nomenclature_indents replacement_indents ON
        indents.goods_nomenclature_sid = replacement_indents.goods_nomenclature_sid
        AND indents.validity_start_date < replacement_indents.validity_start_date
        AND indents.validity_end_date IS NULL
      GROUP BY
        indents.goods_nomenclature_indent_sid,
        indents.goods_nomenclature_sid,
        indents.number_indents,
        indents.goods_nomenclature_item_id,
        indents.productline_suffix,
        indents.validity_start_date,
        indents.validity_end_date,
        nomenclatures.validity_end_date,
        indents.oid
    EOVIEW

    alter_table :goods_nomenclature_tree_nodes do
      add_index :oid, unique: true # needed for concurrent view refresh
      add_index %i[depth position] # primary index
      add_index :goods_nomenclature_sid
    end
  end

  down do
    drop_view :goods_nomenclature_tree_nodes, materialized: true
  end
end

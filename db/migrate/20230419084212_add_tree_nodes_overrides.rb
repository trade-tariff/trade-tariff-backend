Sequel.migration do
  up do
    create_table :goods_nomenclature_tree_node_overrides do
      primary_key :id
      Integer :goods_nomenclature_indent_sid, null: false
      Integer :depth, null: false
      DateTime :created_at, null: false
      DateTime :updated_at
    end

    add_index :goods_nomenclature_tree_node_overrides, :goods_nomenclature_indent_sid, unique: true
    add_index :goods_nomenclature_tree_node_overrides, :created_at
    add_index :goods_nomenclature_tree_node_overrides, :updated_at

    drop_view :goods_nomenclature_tree_nodes, materialized: true

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
        COALESCE(
          overrides.depth,
          indents.number_indents + 2 - (indents.goods_nomenclature_item_id LIKE '%00000000' AND indents.number_indents = 0)::integer + COUNT(grouping_headings.goods_nomenclature_sid)
        ) AS "depth"
      FROM goods_nomenclature_indents indents
      INNER JOIN goods_nomenclatures nomenclatures ON
        indents.goods_nomenclature_sid = nomenclatures.goods_nomenclature_sid
      LEFT JOIN goods_nomenclature_indents replacement_indents ON
        indents.goods_nomenclature_sid = replacement_indents.goods_nomenclature_sid
        AND indents.validity_start_date < replacement_indents.validity_start_date
        AND indents.validity_end_date IS null
      LEFT JOIN goods_nomenclature_tree_node_overrides overrides ON
        indents.goods_nomenclature_indent_sid = overrides.goods_nomenclature_indent_sid
        AND indents.operation_date < coalesce(overrides.updated_at, overrides.created_at)
      LEFT JOIN goods_nomenclatures grouping_headings ON
        indents.goods_nomenclature_item_id NOT LIKE '%00000000'
        AND grouping_headings.producline_suffix < '80'
        AND grouping_headings.goods_nomenclature_item_id = CONCAT(substring(indents.goods_nomenclature_item_id, 1, 4), '000000')
        AND grouping_headings.goods_nomenclature_sid <> indents.goods_nomenclature_sid
        AND (grouping_headings.producline_suffix < indents.productline_suffix OR indents.goods_nomenclature_item_id NOT LIKE '%000000')
        AND grouping_headings.validity_start_date <= indents.validity_start_date
        AND (grouping_headings.validity_end_date IS NULL OR grouping_headings.validity_end_date >= indents.validity_start_date)
      GROUP BY
        indents.goods_nomenclature_indent_sid,
        indents.goods_nomenclature_sid,
        indents.number_indents,
        indents.goods_nomenclature_item_id,
        indents.productline_suffix,
        indents.validity_start_date,
        indents.validity_end_date,
        nomenclatures.validity_end_date,
        indents.oid,
        overrides.depth
    EOVIEW

    alter_table :goods_nomenclature_tree_nodes do
      add_index :oid, unique: true # needed for concurrent view refresh
      add_index %i[depth position] # primary index
      add_index :goods_nomenclature_sid
    end
  end

  down do
    drop_view :goods_nomenclature_tree_nodes, materialized: true

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
      FROM goods_nomenclature_indents indents
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

    drop_table :goods_nomenclature_tree_node_overrides
  end
end

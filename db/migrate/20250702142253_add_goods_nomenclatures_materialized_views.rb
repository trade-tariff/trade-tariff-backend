# frozen_string_literal: true

Sequel.migration do
  up do
    drop_view :goods_nomenclature_tree_nodes, materialized: true
    drop_view :goods_nomenclatures

    create_view :goods_nomenclatures, <<~EOVIEW, materialized: true
      SELECT goods_nomenclatures1.goods_nomenclature_sid,
        goods_nomenclatures1.goods_nomenclature_item_id,
        goods_nomenclatures1.producline_suffix,
        goods_nomenclatures1.validity_start_date,
        goods_nomenclatures1.validity_end_date,
        goods_nomenclatures1.statistical_indicator,
        goods_nomenclatures1.oid,
        goods_nomenclatures1.operation,
        goods_nomenclatures1.operation_date,
        goods_nomenclatures1.filename,
        goods_nomenclatures1.path,
            CASE
                WHEN goods_nomenclatures1.goods_nomenclature_item_id::text ~~ '__00000000'::text THEN NULL::text
                ELSE "left"(goods_nomenclatures1.goods_nomenclature_item_id::text, 4)
            END AS heading_short_code,
        "left"(goods_nomenclatures1.goods_nomenclature_item_id::text, 2) AS chapter_short_code
      FROM goods_nomenclatures_oplog goods_nomenclatures1
      WHERE (goods_nomenclatures1.oid IN ( SELECT max(goods_nomenclatures2.oid) AS max
              FROM goods_nomenclatures_oplog goods_nomenclatures2
              WHERE goods_nomenclatures1.goods_nomenclature_sid = goods_nomenclatures2.goods_nomenclature_sid)) AND goods_nomenclatures1.operation::text <> 'D'::text
      WITH DATA
    EOVIEW

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
        COALESCE(overrides.depth, indents.number_indents + 2 - (indents.goods_nomenclature_item_id LIKE '%00000000' AND indents.number_indents = 0)::integer) AS "depth"
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

    alter_table :goods_nomenclatures do
      add_index :oid, unique: true
      add_index :operation_date
      add_index :validity_end_date
      add_index :validity_start_date
      add_index :goods_nomenclature_sid
      add_index %i[goods_nomenclature_item_id producline_suffix]
      add_index :path, type: :gin
    end

    alter_table :goods_nomenclature_tree_nodes do
      add_index :oid, unique: true # needed for concurrent view refresh
      add_index %i[depth position] # primary index
      add_index :goods_nomenclature_sid
    end
  end

  down do
    drop_view :goods_nomenclature_tree_nodes, materialized: true
    drop_view :goods_nomenclatures, materialized: true

    create_view :goods_nomenclatures, <<~EOVIEW
      SELECT goods_nomenclatures1.goods_nomenclature_sid,
        goods_nomenclatures1.goods_nomenclature_item_id,
        goods_nomenclatures1.producline_suffix,
        goods_nomenclatures1.validity_start_date,
        goods_nomenclatures1.validity_end_date,
        goods_nomenclatures1.statistical_indicator,
        goods_nomenclatures1.oid,
        goods_nomenclatures1.operation,
        goods_nomenclatures1.operation_date,
        goods_nomenclatures1.filename,
        goods_nomenclatures1.path,
            CASE
                WHEN goods_nomenclatures1.goods_nomenclature_item_id::text ~~ '__00000000'::text THEN NULL::text
                ELSE "left"(goods_nomenclatures1.goods_nomenclature_item_id::text, 4)
            END AS heading_short_code,
        "left"(goods_nomenclatures1.goods_nomenclature_item_id::text, 2) AS chapter_short_code
      FROM goods_nomenclatures_oplog goods_nomenclatures1
      WHERE (goods_nomenclatures1.oid IN ( SELECT max(goods_nomenclatures2.oid) AS max
              FROM goods_nomenclatures_oplog goods_nomenclatures2
              WHERE goods_nomenclatures1.goods_nomenclature_sid = goods_nomenclatures2.goods_nomenclature_sid)) AND goods_nomenclatures1.operation::text <> 'D'::text
    EOVIEW

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
        COALESCE(overrides.depth, indents.number_indents + 2 - (indents.goods_nomenclature_item_id LIKE '%00000000' AND indents.number_indents = 0)::integer) AS "depth"
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
end

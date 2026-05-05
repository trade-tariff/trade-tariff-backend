# frozen_string_literal: true

Sequel.migration do
  up do
    drop_view :goods_nomenclature_tree_nodes, materialized: true

    create_view :goods_nomenclature_tree_nodes, <<~EOVIEW, materialized: true
      WITH tree_nodes AS (
        SELECT
          indents.goods_nomenclature_indent_sid,
          indents.goods_nomenclature_sid,
          indents.number_indents,
          indents.goods_nomenclature_item_id,
          indents.productline_suffix,
          CONCAT(indents.goods_nomenclature_item_id, indents.productline_suffix)::bigint AS "position",
          indents.validity_start_date,
          COALESCE(indents.validity_end_date, MIN(replacement_indents.validity_start_date) - INTERVAL '1 second', nomenclatures.validity_end_date) AS validity_end_date,
          indents.oid,
          COALESCE(overrides.depth, indents.number_indents + 2 - (indents.goods_nomenclature_item_id LIKE '%00000000' AND indents.number_indents = 0)::integer) AS "depth"
        FROM goods_nomenclature_indents indents
        INNER JOIN goods_nomenclatures nomenclatures ON
          indents.goods_nomenclature_sid = nomenclatures.goods_nomenclature_sid
        LEFT JOIN goods_nomenclature_indents replacement_indents ON
          indents.goods_nomenclature_sid = replacement_indents.goods_nomenclature_sid
          AND indents.validity_start_date < replacement_indents.validity_start_date
          AND indents.validity_end_date IS NULL
        LEFT JOIN goods_nomenclature_tree_node_overrides overrides ON
          indents.goods_nomenclature_indent_sid = overrides.goods_nomenclature_indent_sid
          AND indents.operation_date < COALESCE(overrides.updated_at, overrides.created_at)
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
      ),
      valid_next_siblings AS (
        SELECT DISTINCT ON (t.goods_nomenclature_indent_sid)
          t.goods_nomenclature_indent_sid,
          COALESCE(s."position", 1000000000000) AS next_sibling_or_end_position,
          s.validity_start_date AS next_sibling_validity_start_date
        FROM tree_nodes t
        LEFT JOIN tree_nodes s ON
          s.depth = t.depth
          AND s."position" > t."position"
          AND (t.validity_end_date IS NULL OR s.validity_start_date <= t.validity_end_date)
          AND (s.validity_end_date IS NULL OR s.validity_end_date >= t.validity_start_date)
        ORDER BY t.goods_nomenclature_indent_sid, s."position" ASC NULLS LAST
      )
      SELECT
        t.*,
        vns.next_sibling_or_end_position,
        vns.next_sibling_validity_start_date
      FROM tree_nodes t
      LEFT JOIN valid_next_siblings vns USING (goods_nomenclature_indent_sid)
    EOVIEW

    alter_table :goods_nomenclature_tree_nodes do
      add_index :oid, unique: true # needed for concurrent view refresh
      add_index %i[depth position] # primary index
      add_index :goods_nomenclature_sid
      add_index :next_sibling_validity_start_date
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
      add_index :oid, unique: true
      add_index %i[depth position]
      add_index :goods_nomenclature_sid
    end
  end
end

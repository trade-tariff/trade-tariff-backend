# frozen_string_literal: true
Sequel.migration do
  up do
    drop_view :base_regulations
    drop_view :modification_regulations
    drop_view :simplified_procedural_code_measures
    drop_view :measures

    create_view :base_regulations, <<~EOVIEW, materialized: true
      SELECT base_regulations1.base_regulation_role,
        base_regulations1.base_regulation_id,
        base_regulations1.validity_start_date,
        base_regulations1.validity_end_date,
        base_regulations1.community_code,
        base_regulations1.regulation_group_id,
        base_regulations1.replacement_indicator,
        base_regulations1.stopped_flag,
        base_regulations1.information_text,
        base_regulations1.approved_flag,
        base_regulations1.published_date,
        base_regulations1.officialjournal_number,
        base_regulations1.officialjournal_page,
        base_regulations1.effective_end_date,
        base_regulations1.antidumping_regulation_role,
        base_regulations1.related_antidumping_regulation_id,
        base_regulations1.complete_abrogation_regulation_role,
        base_regulations1.complete_abrogation_regulation_id,
        base_regulations1.explicit_abrogation_regulation_role,
        base_regulations1.explicit_abrogation_regulation_id,
        base_regulations1."national",
        base_regulations1.oid,
        base_regulations1.operation,
        base_regulations1.operation_date,
        base_regulations1.filename
      FROM base_regulations_oplog base_regulations1
      WHERE (base_regulations1.oid IN ( SELECT max(base_regulations2.oid) AS max
              FROM base_regulations_oplog base_regulations2
              WHERE base_regulations1.base_regulation_id::text = base_regulations2.base_regulation_id::text AND base_regulations1.base_regulation_role = base_regulations2.base_regulation_role)) AND base_regulations1.operation::text <> 'D'::text
      WITH DATA
    EOVIEW

    create_view :modification_regulations, <<~EOVIEW, materialized: true
      SELECT modification_regulations1.modification_regulation_role,
        modification_regulations1.modification_regulation_id,
        modification_regulations1.validity_start_date,
        modification_regulations1.validity_end_date,
        modification_regulations1.published_date,
        modification_regulations1.officialjournal_number,
        modification_regulations1.officialjournal_page,
        modification_regulations1.base_regulation_role,
        modification_regulations1.base_regulation_id,
        modification_regulations1.replacement_indicator,
        modification_regulations1.stopped_flag,
        modification_regulations1.information_text,
        modification_regulations1.approved_flag,
        modification_regulations1.explicit_abrogation_regulation_role,
        modification_regulations1.explicit_abrogation_regulation_id,
        modification_regulations1.effective_end_date,
        modification_regulations1.complete_abrogation_regulation_role,
        modification_regulations1.complete_abrogation_regulation_id,
        modification_regulations1.oid,
        modification_regulations1.operation,
        modification_regulations1.operation_date,
        modification_regulations1.filename
      FROM modification_regulations_oplog modification_regulations1
      WHERE (modification_regulations1.oid IN ( SELECT max(modification_regulations2.oid) AS max
              FROM modification_regulations_oplog modification_regulations2
              WHERE modification_regulations1.modification_regulation_id::text = modification_regulations2.modification_regulation_id::text AND modification_regulations1.modification_regulation_role = modification_regulations2.modification_regulation_role)) AND modification_regulations1.operation::text <> 'D'::text
      WITH DATA
    EOVIEW

    create_view :measures, <<~EOVIEW, materialized: true
      SELECT measures1.measure_sid,
        measures1.measure_type_id,
        measures1.geographical_area_id,
        measures1.goods_nomenclature_item_id,
        measures1.validity_start_date,
        measures1.validity_end_date,
        measures1.measure_generating_regulation_role,
        measures1.measure_generating_regulation_id,
        measures1.justification_regulation_role,
        measures1.justification_regulation_id,
        measures1.stopped_flag,
        measures1.geographical_area_sid,
        measures1.goods_nomenclature_sid,
        measures1.ordernumber,
        measures1.additional_code_type_id,
        measures1.additional_code_id,
        measures1.additional_code_sid,
        measures1.reduction_indicator,
        measures1.export_refund_nomenclature_sid,
        measures1."national",
        measures1.tariff_measure_number,
        measures1.invalidated_by,
        measures1.invalidated_at,
        measures1.oid,
        measures1.operation,
        measures1.operation_date,
        measures1.filename
      FROM measures_oplog measures1
      WHERE (measures1.oid IN ( SELECT max(measures2.oid) AS max
              FROM measures_oplog measures2
              WHERE measures1.measure_sid = measures2.measure_sid)) AND measures1.operation::text <> 'D'::text
          WITH DATA
    EOVIEW

    create_view :simplified_procedural_code_measures, <<~EOVIEW
      SELECT simplified_procedural_codes.simplified_procedural_code,
        measures.validity_start_date,
        measures.validity_end_date,
        string_agg(DISTINCT simplified_procedural_codes.goods_nomenclature_item_id, ', '::text) AS goods_nomenclature_item_ids,
        max(measure_components.duty_amount) AS duty_amount,
        max(measure_components.monetary_unit_code::text) AS monetary_unit_code,
        max(measure_components.measurement_unit_code::text) AS measurement_unit_code,
        max(measure_components.measurement_unit_qualifier_code::text) AS measurement_unit_qualifier_code,
        max(simplified_procedural_codes.goods_nomenclature_label) AS goods_nomenclature_label
       FROM measures
         JOIN measure_components ON measures.measure_sid = measure_components.measure_sid
         RIGHT JOIN simplified_procedural_codes ON measures.goods_nomenclature_item_id::text = simplified_procedural_codes.goods_nomenclature_item_id AND measures.measure_type_id::text = '488'::text AND measures.validity_end_date > '2021-01-01'::date AND measures.geographical_area_id::text = '1011'::text
         GROUP BY simplified_procedural_codes.simplified_procedural_code, measures.validity_start_date, measures.validity_end_date
    EOVIEW

    add_index :base_regulations, :oid, unique: true
    add_index :modification_regulations, :oid, unique: true
    add_index :measures, :oid, unique: true
  end

  down do
    drop_view :base_regulations, materialized: true
    drop_view :modification_regulations, materialized: true
    drop_view :simplified_procedural_code_measures
    drop_view :measures, materialized: true

    create_view :base_regulations, <<~EOVIEW
      SELECT base_regulations1.base_regulation_role,
        base_regulations1.base_regulation_id,
        base_regulations1.validity_start_date,
        base_regulations1.validity_end_date,
        base_regulations1.community_code,
        base_regulations1.regulation_group_id,
        base_regulations1.replacement_indicator,
        base_regulations1.stopped_flag,
        base_regulations1.information_text,
        base_regulations1.approved_flag,
        base_regulations1.published_date,
        base_regulations1.officialjournal_number,
        base_regulations1.officialjournal_page,
        base_regulations1.effective_end_date,
        base_regulations1.antidumping_regulation_role,
        base_regulations1.related_antidumping_regulation_id,
        base_regulations1.complete_abrogation_regulation_role,
        base_regulations1.complete_abrogation_regulation_id,
        base_regulations1.explicit_abrogation_regulation_role,
        base_regulations1.explicit_abrogation_regulation_id,
        base_regulations1."national",
        base_regulations1.oid,
        base_regulations1.operation,
        base_regulations1.operation_date,
        base_regulations1.filename
      FROM base_regulations_oplog base_regulations1
      WHERE (base_regulations1.oid IN ( SELECT max(base_regulations2.oid) AS max
              FROM base_regulations_oplog base_regulations2
              WHERE base_regulations1.base_regulation_id::text = base_regulations2.base_regulation_id::text AND base_regulations1.base_regulation_role = base_regulations2.base_regulation_role)) AND base_regulations1.operation::text <> 'D'::text
    EOVIEW

    create_view :modification_regulations, <<~EOVIEW
      SELECT modification_regulations1.modification_regulation_role,
        modification_regulations1.modification_regulation_id,
        modification_regulations1.validity_start_date,
        modification_regulations1.validity_end_date,
        modification_regulations1.published_date,
        modification_regulations1.officialjournal_number,
        modification_regulations1.officialjournal_page,
        modification_regulations1.base_regulation_role,
        modification_regulations1.base_regulation_id,
        modification_regulations1.replacement_indicator,
        modification_regulations1.stopped_flag,
        modification_regulations1.information_text,
        modification_regulations1.approved_flag,
        modification_regulations1.explicit_abrogation_regulation_role,
        modification_regulations1.explicit_abrogation_regulation_id,
        modification_regulations1.effective_end_date,
        modification_regulations1.complete_abrogation_regulation_role,
        modification_regulations1.complete_abrogation_regulation_id,
        modification_regulations1.oid,
        modification_regulations1.operation,
        modification_regulations1.operation_date,
        modification_regulations1.filename
      FROM modification_regulations_oplog modification_regulations1
      WHERE (modification_regulations1.oid IN ( SELECT max(modification_regulations2.oid) AS max
              FROM modification_regulations_oplog modification_regulations2
              WHERE modification_regulations1.modification_regulation_id::text = modification_regulations2.modification_regulation_id::text AND modification_regulations1.modification_regulation_role = modification_regulations2.modification_regulation_role)) AND modification_regulations1.operation::text <> 'D'::text
    EOVIEW

    create_view :measures, <<~EOVIEW
      SELECT measures1.measure_sid,
        measures1.measure_type_id,
        measures1.geographical_area_id,
        measures1.goods_nomenclature_item_id,
        measures1.validity_start_date,
        measures1.validity_end_date,
        measures1.measure_generating_regulation_role,
        measures1.measure_generating_regulation_id,
        measures1.justification_regulation_role,
        measures1.justification_regulation_id,
        measures1.stopped_flag,
        measures1.geographical_area_sid,
        measures1.goods_nomenclature_sid,
        measures1.ordernumber,
        measures1.additional_code_type_id,
        measures1.additional_code_id,
        measures1.additional_code_sid,
        measures1.reduction_indicator,
        measures1.export_refund_nomenclature_sid,
        measures1."national",
        measures1.tariff_measure_number,
        measures1.invalidated_by,
        measures1.invalidated_at,
        measures1.oid,
        measures1.operation,
        measures1.operation_date,
        measures1.filename
      FROM measures_oplog measures1
      WHERE (measures1.oid IN ( SELECT max(measures2.oid) AS max
              FROM measures_oplog measures2
              WHERE measures1.measure_sid = measures2.measure_sid)) AND measures1.operation::text <> 'D'::text
    EOVIEW

    create_view :simplified_procedural_code_measures, <<~EOVIEW
      SELECT simplified_procedural_codes.simplified_procedural_code,
        measures.validity_start_date,
        measures.validity_end_date,
        string_agg(DISTINCT simplified_procedural_codes.goods_nomenclature_item_id, ', '::text) AS goods_nomenclature_item_ids,
        max(measure_components.duty_amount) AS duty_amount,
        max(measure_components.monetary_unit_code::text) AS monetary_unit_code,
        max(measure_components.measurement_unit_code::text) AS measurement_unit_code,
        max(measure_components.measurement_unit_qualifier_code::text) AS measurement_unit_qualifier_code,
        max(simplified_procedural_codes.goods_nomenclature_label) AS goods_nomenclature_label
       FROM measures
         JOIN measure_components ON measures.measure_sid = measure_components.measure_sid
         RIGHT JOIN simplified_procedural_codes ON measures.goods_nomenclature_item_id::text = simplified_procedural_codes.goods_nomenclature_item_id AND measures.measure_type_id::text = '488'::text AND measures.validity_end_date > '2021-01-01'::date AND measures.geographical_area_id::text = '1011'::text
         GROUP BY simplified_procedural_codes.simplified_procedural_code, measures.validity_start_date, measures.validity_end_date
    EOVIEW
  end
end

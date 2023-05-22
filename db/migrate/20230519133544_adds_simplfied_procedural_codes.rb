Sequel.migration do
  up do
    create_table :simplified_procedural_codes do
      String :simplified_procedural_code
      String :goods_nomenclature_item_id
      String :goods_nomenclature_label
      DateTime :created_at
      DateTime :updated_at
      primary_key %i[simplified_procedural_code goods_nomenclature_item_id]
    end

    run %{
      CREATE OR REPLACE VIEW simplified_procedural_code_measures AS
      SELECT
        simplified_procedural_codes.simplified_procedural_code,
        measures.validity_start_date,
        measures.validity_end_date,
        STRING_AGG(DISTINCT simplified_procedural_codes.goods_nomenclature_item_id, ', ') as goods_nomenclature_item_ids,
        MAX(measure_components.duty_amount) as duty_amount,
        MAX(measure_components.monetary_unit_code) as monetary_unit_code,
        MAX(simplified_procedural_codes.goods_nomenclature_label) as goods_nomenclature_label
      FROM measures
      INNER JOIN measure_components
      ON measures.measure_sid = measure_components.measure_sid
      RIGHT JOIN simplified_procedural_codes
      ON measures.goods_nomenclature_item_id = simplified_procedural_codes.goods_nomenclature_item_id
      AND measures.measure_type_id = '488'
      AND measures.validity_end_date > '2021-01-01'::date
      GROUP BY
        simplified_procedural_codes.simplified_procedural_code,
        measures.validity_start_date,
        measures.validity_end_date
    }
  end

  down do
    drop_view :simplified_procedural_code_measures
    drop_table :simplified_procedural_codes
  end
end

# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table :geographical_areas do
      add_index :operation_date
      add_index :geographical_area_sid
      add_index :geographical_area_id
      add_index :parent_geographical_area_group_sid
    end

    alter_table :geographical_area_descriptions do
      add_index :operation_date
      add_index [:geographical_area_description_period_sid, :geographical_area_sid]
      add_index :language_id
    end

    alter_table :geographical_area_description_periods do
      add_index :operation_date
      add_index [:geographical_area_description_period_sid, :geographical_area_sid]
    end

    alter_table :measure_excluded_geographical_areas do
      add_index :operation_date
      add_index :geographical_area_sid
      add_index [:measure_sid, :excluded_geographical_area, :geographical_area_sid]
    end

    alter_table :geographical_area_memberships do
      add_index :operation_date
      add_index [:geographical_area_sid, :geographical_area_group_sid, :validity_start_date]
    end

    alter_table :additional_codes do
      add_index :operation_date
      add_index :additional_code_sid
      add_index :additional_code_type_id
    end

    alter_table :additional_code_types do
      add_index :operation_date
      add_index :meursing_table_plan_id
      add_index :additional_code_type_id
    end

    alter_table :additional_code_type_measure_types do
      add_index :operation_date
      add_index [:measure_type_id, :additional_code_type_id]
    end

    alter_table :additional_code_type_descriptions do
      add_index :operation_date
      add_index :additional_code_type_id
      add_index :language_id
    end

    alter_table :additional_code_descriptions do
      add_index :operation_date
      add_index [:additional_code_description_period_sid, :additional_code_type_id, :additional_code_sid], name: :additional_code_descriptions_additional_code
      add_index :language_id
      add_index :additional_code_description_period_sid
      add_index :additional_code_sid
      add_index :additional_code_type_id
    end

    alter_table :additional_code_description_periods do
      add_index :operation_date
      add_index :additional_code_type_id
      add_index :additional_code_description_period_sid
      add_index [:additional_code_description_period_sid, :additional_code_sid, :additional_code_type_id], name: :additional_code_description_periods_additional_code
    end

    alter_table :base_regulations do
      add_index :operation_date
      add_index :validity_start_date
      add_index :validity_end_date
      add_index :effective_end_date
      add_index :approved_flag
      add_index [:antidumping_regulation_role, :related_antidumping_regulation_id]
      add_index [:base_regulation_id, :base_regulation_role]
      add_index [:complete_abrogation_regulation_role, :complete_abrogation_regulation_id]
      add_index [:explicit_abrogation_regulation_role, :explicit_abrogation_regulation_id]
      add_index :regulation_group_id
    end

    alter_table :modification_regulations do
      add_index :operation_date
      add_index :validity_start_date
      add_index :validity_end_date
      add_index :effective_end_date
      add_index :approved_flag
      add_index [:modification_regulation_id, :modification_regulation_role]
      add_index [:base_regulation_id, :base_regulation_role]
      add_index [:complete_abrogation_regulation_role, :complete_abrogation_regulation_id]
      add_index [:explicit_abrogation_regulation_role, :explicit_abrogation_regulation_id]
    end

    alter_table :measures do
      add_index :measure_sid
      add_index :measure_type_id
      add_index :measure_generating_regulation_id
      add_index :measure_generating_regulation_role
      add_index [:justification_regulation_role, :justification_regulation_id]
      add_index :additional_code_type_id
      add_index :additional_code_id
      add_index :additional_code_sid
      add_index :goods_nomenclature_item_id, name: :measures_view_goods_nomenclature_item_id_index
      add_index :goods_nomenclature_sid
      add_index :export_refund_nomenclature_sid,  name: :measures_view_export_refund_nomenclature_sid_index
      add_index :geographical_area_sid
      add_index :validity_start_date
      add_index :validity_end_date
      add_index :operation_date
      add_index [:ordernumber, :validity_start_date]
    end
  end

  down do
    alter_table :geographical_areas do
      drop_index :operation_date
      drop_index :geographical_area_sid
      drop_index :geographical_area_id
      drop_index :parent_geographical_area_group_sid
    end

    alter_table :geographical_area_descriptions do
      drop_index :operation_date
      drop_index [:geographical_area_description_period_sid, :geographical_area_sid]
      drop_index :language_id
    end

    alter_table :geographical_area_description_periods do
      drop_index :operation_date
      drop_index [:geographical_area_description_period_sid, :geographical_area_sid]
    end

    alter_table :measure_excluded_geographical_areas do
      drop_index :operation_date
      drop_index :geographical_area_sid
      drop_index [:measure_sid, :excluded_geographical_area, :geographical_area_sid]
    end

    alter_table :geographical_area_memberships do
      drop_index :operation_date
      drop_index [:geographical_area_sid, :geographical_area_group_sid, :validity_start_date]
    end

    alter_table :additional_codes do
      drop_index :operation_date
      drop_index :additional_code_sid
      drop_index :additional_code_type_id
    end

    alter_table :additional_code_types do
      drop_index :operation_date
      drop_index :meursing_table_plan_id
      drop_index :additional_code_type_id
    end

    alter_table :additional_code_type_measure_types do
      drop_index :operation_date
      drop_index [:measure_type_id, :additional_code_type_id]
    end

    alter_table :additional_code_type_descriptions do
      drop_index :operation_date
      drop_index :additional_code_type_id
      drop_index :language_id
    end

    alter_table :additional_code_descriptions do
      drop_index :operation_date
      drop_index [:additional_code_description_period_sid, :additional_code_type_id, :additional_code_sid], name: :additional_code_descriptions_additional_code
      drop_index :language_id
      drop_index :additional_code_description_period_sid
      drop_index :additional_code_sid
      drop_index :additional_code_type_id
    end

    alter_table :additional_code_description_periods do
      drop_index :operation_date
      drop_index :additional_code_type_id
      drop_index :additional_code_description_period_sid
      drop_index [:additional_code_description_period_sid, :additional_code_sid, :additional_code_type_id], name: :additional_code_description_periods_additional_code
    end

    alter_table :base_regulations do
      drop_index :operation_date
      drop_index :validity_start_date
      drop_index :validity_end_date
      drop_index :effective_end_date
      drop_index :approved_flag
      drop_index [:antidumping_regulation_role, :related_antidumping_regulation_id]
      drop_index [:base_regulation_id, :base_regulation_role]
      drop_index [:complete_abrogation_regulation_role, :complete_abrogation_regulation_id]
      drop_index [:explicit_abrogation_regulation_role, :explicit_abrogation_regulation_id]
      drop_index :regulation_group_id
    end

    alter_table :modification_regulations do
      drop_index :operation_date
      drop_index :validity_start_date
      drop_index :validity_end_date
      drop_index :effective_end_date
      drop_index :approved_flag
      drop_index [:modification_regulation_id, :modification_regulation_role]
      drop_index [:base_regulation_id, :base_regulation_role]
      drop_index [:complete_abrogation_regulation_role, :complete_abrogation_regulation_id]
      drop_index [:explicit_abrogation_regulation_role, :explicit_abrogation_regulation_id]
    end

    alter_table :measures do
      drop_index :measure_sid
      drop_index :measure_type_id
      drop_index :measure_generating_regulation_id
      drop_index :measure_generating_regulation_role
      drop_index [:justification_regulation_role, :justification_regulation_id]
      drop_index :additional_code_type_id
      drop_index :additional_code_id
      drop_index :additional_code_sid
      drop_index :goods_nomenclature_item_id, name: :measures_view_goods_nomenclature_item_id_index
      drop_index :goods_nomenclature_sid
      drop_index :export_refund_nomenclature_sid,  name: :measures_view_export_refund_nomenclature_sid_index
      drop_index :geographical_area_sid
      drop_index :validity_start_date
      drop_index :validity_end_date
      drop_index :operation_date
      drop_index [:ordernumber, :validity_start_date]
    end
  end
end

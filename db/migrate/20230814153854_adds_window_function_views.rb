Sequel.migration do
  up do
    raise NotImplementedError, 'This migration is a WIP'
    drop_view :goods_nomenclature_tree_nodes, materialized: true
    drop_view :simplified_procedural_code_measures

    run %Q(
      DROP VIEW additional_code_description_periods;
      DROP VIEW additional_code_descriptions;
      DROP VIEW additional_code_type_descriptions;
      DROP VIEW additional_code_type_measure_types;
      DROP VIEW additional_code_types;
      DROP VIEW additional_codes;
      DROP VIEW base_regulations;
      DROP VIEW certificate_description_periods;
      DROP VIEW certificate_descriptions;
      DROP VIEW certificate_type_descriptions;
      DROP VIEW certificate_types;
      DROP VIEW certificates;
      DROP VIEW complete_abrogation_regulations;
      DROP VIEW duty_expression_descriptions;
      DROP VIEW duty_expressions;
      DROP VIEW explicit_abrogation_regulations;
      DROP VIEW export_refund_nomenclature_description_periods;
      DROP VIEW export_refund_nomenclature_descriptions;
      DROP VIEW export_refund_nomenclature_indents;
      DROP VIEW export_refund_nomenclatures;
      DROP VIEW footnote_association_additional_codes;
      DROP VIEW footnote_association_erns;
      DROP VIEW footnote_association_goods_nomenclatures;
      DROP VIEW footnote_association_measures;
      DROP VIEW footnote_association_meursing_headings;
      DROP VIEW footnote_description_periods;
      DROP VIEW footnote_descriptions;
      DROP VIEW footnote_type_descriptions;
      DROP VIEW footnote_types;
      DROP VIEW footnotes;
      DROP VIEW fts_regulation_actions;
      DROP VIEW full_temporary_stop_regulations;
      DROP VIEW geographical_area_description_periods;
      DROP VIEW geographical_area_descriptions;
      DROP VIEW geographical_area_memberships;
      DROP VIEW geographical_areas;
      DROP VIEW goods_nomenclature_description_periods;
      DROP VIEW goods_nomenclature_descriptions;
      DROP VIEW goods_nomenclature_group_descriptions;
      DROP VIEW goods_nomenclature_groups;
      DROP VIEW goods_nomenclature_indents;
      DROP VIEW goods_nomenclature_origins;
      DROP VIEW goods_nomenclature_successors;
      DROP VIEW goods_nomenclatures;
      DROP VIEW language_descriptions;
      DROP VIEW languages;
      DROP VIEW measure_action_descriptions;
      DROP VIEW measure_actions;
      DROP VIEW measure_components;
      DROP VIEW measure_condition_code_descriptions;
      DROP VIEW measure_condition_codes;
      DROP VIEW measure_condition_components;
      DROP VIEW measure_conditions;
      DROP VIEW measure_excluded_geographical_areas;
      DROP VIEW measure_partial_temporary_stops;
      DROP VIEW measure_type_descriptions;
      DROP VIEW measure_type_series;
      DROP VIEW measure_type_series_descriptions;
      DROP VIEW measure_types;
      DROP VIEW measurement_unit_descriptions;
      DROP VIEW measurement_unit_qualifier_descriptions;
      DROP VIEW measurement_unit_qualifiers;
      DROP VIEW measurement_units;
      DROP VIEW measurements;
      DROP VIEW measures;
      DROP VIEW meursing_additional_codes;
      DROP VIEW meursing_heading_texts;
      DROP VIEW meursing_headings;
      DROP VIEW meursing_subheadings;
      DROP VIEW meursing_table_cell_components;
      DROP VIEW meursing_table_plans;
      DROP VIEW modification_regulations;
      DROP VIEW monetary_exchange_periods;
      DROP VIEW monetary_exchange_rates;
      DROP VIEW monetary_unit_descriptions;
      DROP VIEW monetary_units;
      DROP VIEW nomenclature_group_memberships;
      DROP VIEW prorogation_regulation_actions;
      DROP VIEW prorogation_regulations;
      DROP VIEW publication_sigles;
      DROP VIEW quota_associations;
      DROP VIEW quota_balance_events;
      DROP VIEW quota_blocking_periods;
      DROP VIEW quota_closed_and_transferred_events;
      DROP VIEW quota_critical_events;
      DROP VIEW quota_definitions;
      DROP VIEW quota_exhaustion_events;
      DROP VIEW quota_order_number_origin_exclusions;
      DROP VIEW quota_order_number_origins;
      DROP VIEW quota_order_numbers;
      DROP VIEW quota_reopening_events;
      DROP VIEW quota_suspension_periods;
      DROP VIEW quota_unblocking_events;
      DROP VIEW quota_unsuspension_events;
      DROP VIEW regulation_group_descriptions;
      DROP VIEW regulation_groups;
      DROP VIEW regulation_replacements;
      DROP VIEW regulation_role_type_descriptions;
      DROP VIEW regulation_role_types;
      DROP VIEW transmission_comments;

      CREATE OR REPLACE VIEW additional_code_description_periods AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY additional_code_description_period_sid, additional_code_sid, additional_code_type_id) AS max_oid
        FROM additional_code_description_periods_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW additional_code_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY additional_code_description_period_sid, additional_code_sid) AS max_oid
        FROM additional_code_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW additional_code_type_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY additional_code_type_id, language_id) AS max_oid
        FROM additional_code_type_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW additional_code_type_measure_types AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY measure_type_id, additional_code_type_id) AS max_oid
        FROM additional_code_type_measure_types_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW additional_code_types AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY additional_code_type_id) AS max_oid
        FROM additional_code_types_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW additional_codes AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY additional_code_sid) AS max_oid
        FROM additional_codes_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW base_regulations AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY base_regulation_id, base_regulation_role) AS max_oid
        FROM base_regulations_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW certificate_description_periods AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY certificate_description_period_sid) AS max_oid
        FROM certificate_description_periods_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW certificate_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY certificate_description_period_sid) AS max_oid
        FROM certificate_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW certificate_type_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY certificate_type_code, language_id) AS max_oid
        FROM certificate_type_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW certificate_types AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY certificate_type_code) AS max_oid
        FROM certificate_types_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW certificates AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY certificate_type_code, certificate_code) AS max_oid
        FROM certificates_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW complete_abrogation_regulations AS
      SELECT *
      FROM (
       SELECT *,
         MAX(oid) OVER(PARTITION BY complete_abrogation_regulation_id, complete_abrogation_regulation_role) AS max_oid
       FROM complete_abrogation_regulations_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW duty_expression_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY duty_expression_id, language_id) AS max_oid
        FROM duty_expression_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW duty_expressions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY duty_expression_id) AS max_oid
        FROM duty_expressions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW explicit_abrogation_regulations AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY explicit_abrogation_regulation_id, explicit_abrogation_regulation_role) AS max_oid
        FROM explicit_abrogation_regulations_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW export_refund_nomenclature_description_periods AS
      SELECT *
      FROM (
       SELECT *,
         MAX(oid) OVER(PARTITION BY export_refund_nomenclature_description_period_sid) AS max_oid
       FROM export_refund_nomenclature_description_periods_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW export_refund_nomenclature_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY export_refund_nomenclature_description_period_sid) AS max_oid
        FROM export_refund_nomenclature_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW export_refund_nomenclature_indents AS
      SELECT *
      FROM (
       SELECT *,
         MAX(oid) OVER(PARTITION BY export_refund_nomenclature_indents_sid) AS max_oid
       FROM export_refund_nomenclature_indents_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW export_refund_nomenclatures AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY export_refund_nomenclature_sid) AS max_oid
        FROM export_refund_nomenclatures_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW footnote_association_additional_codes AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY footnote_type_id, footnote_id, additional_code_sid) AS max_oid
        FROM footnote_association_additional_codes_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW footnote_association_erns AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY export_refund_nomenclature_sid, footnote_type, footnote_id) AS max_oid
        FROM footnote_association_erns_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW footnote_association_goods_nomenclatures AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY footnote_type, footnote_id, goods_nomenclature_sid) AS max_oid
        FROM footnote_association_goods_nomenclatures_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW footnote_association_measures AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY measure_sid, footnote_type_id, footnote_id) AS max_oid
        FROM footnote_association_measures_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW footnote_association_meursing_headings AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY footnote_id, meursing_table_plan_id) AS max_oid
        FROM footnote_association_meursing_headings_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW footnote_description_periods AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY footnote_type_id, footnote_id, footnote_description_period_sid) AS max_oid
        FROM footnote_description_periods_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW footnote_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY footnote_description_period_sid, footnote_type_id, footnote_id, language_id) AS max_oid
        FROM footnote_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW footnote_type_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY footnote_type_id, language_id) AS max_oid
        FROM footnote_type_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW footnote_types AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY footnote_type_id) AS max_oid
        FROM footnote_types_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW footnotes AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY footnote_type_id, footnote_id) AS max_oid
        FROM footnotes_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW fts_regulation_actions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY fts_regulation_id, fts_regulation_role, stopped_regulation_id, stopped_regulation_role) AS max_oid
        FROM fts_regulation_actions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW full_temporary_stop_regulations AS
      SELECT *
      FROM (
       SELECT *,
         MAX(oid) OVER(PARTITION BY full_temporary_stop_regulation_id, full_temporary_stop_regulation_role) AS max_oid
       FROM full_temporary_stop_regulations_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW geographical_area_description_periods AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY geographical_area_description_period_sid, geographical_area_sid) AS max_oid
        FROM geographical_area_description_periods_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW geographical_area_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY geographical_area_description_period_sid, geographical_area_sid, language_id) AS max_oid
        FROM geographical_area_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW geographical_area_memberships AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY geographical_area_sid, geographical_area_group_sid, validity_start_date) AS max_oid
        FROM geographical_area_memberships_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW geographical_areas AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY geographical_area_sid) AS max_oid
        FROM geographical_areas_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW goods_nomenclature_description_periods AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY goods_nomenclature_description_period_sid) AS max_oid
        FROM goods_nomenclature_description_periods_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW goods_nomenclature_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY goods_nomenclature_sid, goods_nomenclature_description_period_sid) AS max_oid
        FROM goods_nomenclature_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW goods_nomenclature_group_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY goods_nomenclature_group_id, goods_nomenclature_group_type) AS max_oid
        FROM goods_nomenclature_group_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW goods_nomenclature_groups AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY goods_nomenclature_group_id, goods_nomenclature_group_type) AS max_oid
        FROM goods_nomenclature_groups_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW goods_nomenclature_indents AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY goods_nomenclature_indent_sid) AS max_oid
        FROM goods_nomenclature_indents_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW goods_nomenclature_origins AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY goods_nomenclature_sid, derived_goods_nomenclature_item_id, derived_productline_suffix, goods_nomenclature_item_id, productline_suffix) AS max_oid
        FROM goods_nomenclature_origins_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW goods_nomenclature_successors AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY goods_nomenclature_sid, absorbed_goods_nomenclature_item_id, absorbed_productline_suffix, goods_nomenclature_item_id, productline_suffix) AS max_oid
        FROM goods_nomenclature_successors_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW goods_nomenclatures AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY goods_nomenclature_sid) AS max_oid,
          CASE
            WHEN ((goods_nomenclatures_oplog.goods_nomenclature_item_id)::text ~~ '__00000000'::text) THEN NULL::text
            ELSE LEFT((goods_nomenclatures_oplog.goods_nomenclature_item_id)::text, 4)
          END AS heading_short_code,
          LEFT((goods_nomenclatures_oplog.goods_nomenclature_item_id)::text, 2) AS chapter_short_code
        FROM goods_nomenclatures_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW language_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY language_id, language_code_id) AS max_oid
        FROM language_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW languages AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY language_id) AS max_oid
        FROM languages_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measure_action_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY action_code, language_id) AS max_oid
        FROM measure_action_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measure_actions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY action_code) AS max_oid
        FROM measure_actions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measure_components AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY measure_sid, duty_expression_id) AS max_oid
        FROM measure_components_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measure_condition_code_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY condition_code, language_id) AS max_oid
        FROM measure_condition_code_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measure_condition_codes AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY condition_code) AS max_oid
        FROM measure_condition_codes_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measure_condition_components AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY measure_condition_sid, duty_expression_id) AS max_oid
        FROM measure_condition_components_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measure_conditions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY measure_condition_sid) AS max_oid
        FROM measure_conditions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measure_excluded_geographical_areas AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY measure_sid, geographical_area_sid) AS max_oid
        FROM measure_excluded_geographical_areas_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measure_partial_temporary_stops AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY measure_sid, partial_temporary_stop_regulation_id) AS max_oid
        FROM measure_partial_temporary_stops_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measure_type_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY measure_type_id, language_id) AS max_oid
        FROM measure_type_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measure_type_series AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY measure_type_series_id) AS max_oid
        FROM measure_type_series_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measure_type_series_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY measure_type_series_id) AS max_oid
        FROM measure_type_series_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measure_types AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY measure_type_id) AS max_oid
        FROM measure_types_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measurement_unit_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY measurement_unit_code, language_id) AS max_oid
        FROM measurement_unit_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measurement_unit_qualifier_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY measurement_unit_qualifier_code, language_id) AS max_oid
        FROM measurement_unit_qualifier_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measurement_unit_qualifiers AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY measurement_unit_qualifier_code) AS max_oid
        FROM measurement_unit_qualifiers_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measurement_units AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY measurement_unit_code) AS max_oid
        FROM measurement_units_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measurements AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY measurement_unit_code, measurement_unit_qualifier_code) AS max_oid
        FROM measurements_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW measures AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY measure_sid) AS max_oid
        FROM measures_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW meursing_additional_code AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY meursing_additional_code_sid) AS max_oid
        FROM meursing_additional_codes_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW meursing_heading_texts AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY meursing_table_plan_id, meursing_heading_number, row_column_code, language_id) AS max_oid
        FROM meursing_heading_texts_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW meursing_headings AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY meursing_table_plan_id, meursing_heading_number, row_column_code) AS max_oid
        FROM meursing_headings_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW meursing_subheadings AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY meursing_table_plan_id, meursing_heading_number, row_column_code, subheading_sequence_number) AS max_oid
        FROM meursing_subheadings_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW meursing_table_cell_components AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY meursing_table_plan_id, heading_number, row_column_code, meursing_additional_code_sid) AS max_oid
        FROM meursing_table_cell_components_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW meursing_table_plans AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY meursing_table_plan_id) AS max_oid
        FROM meursing_table_plans_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW modification_regulations AS
      SELECT *
      FROM (
         SELECT *,
         MAX(oid) OVER(PARTITION BY modification_regulation_id, modification_regulation_role) AS max_oid
         FROM modification_regulations_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW monetary_exchange_periods AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY monetary_exchange_period_sid, parent_monetary_unit_code) AS max_oid
        FROM monetary_exchange_periods_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW monetary_exchange_rates AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY monetary_exchange_period_sid, child_monetary_unit_code) AS max_oid
        FROM monetary_exchange_rates_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW monetary_unit_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY monetary_unit_code, language_id) AS max_oid
        FROM monetary_unit_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW monetary_units AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY monetary_unit_code) AS max_oid
        FROM monetary_units_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW nomenclature_group_memberships AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY goods_nomenclature_sid, goods_nomenclature_group_id, goods_nomenclature_group_type, goods_nomenclature_item_id, validity_start_date) AS max_oid
        FROM nomenclature_group_memberships_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW prorogation_regulation_actions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY prorogation_regulation_id, prorogated_regulation_id, prorogated_regulation_role) AS max_oid
        FROM prorogation_regulation_actions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW prorogation_regulations AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY prorogation_regulation_id, prorogation_regulation_role) AS max_oid
        FROM prorogation_regulations_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW publication_sigles AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY code_type_id, code) AS max_oid
        FROM publication_sigles_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW quota_associations AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY main_quota_definition_sid, sub_quota_definition_sid) AS max_oid
        FROM quota_associations_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW quota_balance_events AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY quota_definition_sid, occurrence_timestamp) AS max_oid
        FROM quota_balance_events_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW quota_blocking_periods AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY quota_blocking_period_sid) AS max_oid
        FROM quota_blocking_periods_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW quota_closed_and_transferred_events AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY quota_definition_sid, occurrence_timestamp) AS max_oid
        FROM quota_closed_and_transferred_events_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW quota_critical_events AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY quota_definition_sid, occurrence_timestamp) AS max_oid
        FROM quota_critical_events_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW quota_definitions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY quota_definition_sid) AS max_oid
        FROM quota_definitions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW quota_exhaustion_events AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY quota_definition_sid, occurrence_timestamp) AS max_oid
        FROM quota_exhaustion_events_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW quota_order_number_origin_exclusions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY quota_order_number_origin_sid, excluded_geographical_area_sid) AS max_oid
        FROM quota_order_number_origin_exclusions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW quota_order_number_origins AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY quota_order_number_origin_sid) AS max_oid
        FROM quota_order_number_origins_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW quota_order_numbers AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY quota_order_number_sid) AS max_oid
        FROM quota_order_numbers_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW quota_reopening_events AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY quota_definition_sid, occurrence_timestamp) AS max_oid
        FROM quota_reopening_events_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW quota_suspension_periods AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY quota_suspension_period_sid) AS max_oid
        FROM quota_suspension_periods_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW quota_unblocking_events AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY quota_definition_sid, occurrence_timestamp) AS max_oid
        FROM quota_unblocking_events_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW quota_unsuspension_events AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY quota_definition_sid, occurrence_timestamp) AS max_oid
        FROM quota_unsuspension_events_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW regulation_group_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY regulation_group_id, language_id) AS max_oid
        FROM regulation_group_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW regulation_groups AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY regulation_group_id) AS max_oid
        FROM regulation_groups_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW regulation_replacements AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY replacing_regulation_id, replacing_regulation_role, replaced_regulation_id, replaced_regulation_role) AS max_oid
        FROM regulation_replacements_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW regulation_role_type_descriptions AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY regulation_role_type_id, language_id) AS max_oid
        FROM regulation_role_type_descriptions_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW regulation_role_types AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY regulation_role_type_id) AS max_oid
        FROM regulation_role_types_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW transmission_comments AS
      SELECT *
      FROM (
        SELECT *,
          MAX(oid) OVER(PARTITION BY comment_sid, language_id) AS max_oid
        FROM transmission_comments_oplog
      ) subquery
      WHERE operation <> 'D';

      CREATE OR REPLACE VIEW simplified_procedural_code_measures AS
      SELECT
        simplified_procedural_codes.simplified_procedural_code,
        measures.validity_start_date,
        measures.validity_end_date,
        STRING_AGG(DISTINCT simplified_procedural_codes.goods_nomenclature_item_id, ', ') as goods_nomenclature_item_ids,
        MAX(measure_components.duty_amount) as duty_amount,
        MAX(measure_components.monetary_unit_code) as monetary_unit_code,
        MAX(measure_components.measurement_unit_code) as measurement_unit_code,
        MAX(measure_components.measurement_unit_qualifier_code) as measurement_unit_qualifier_code,
        MAX(simplified_procedural_codes.goods_nomenclature_label) as goods_nomenclature_label
      FROM measures
      INNER JOIN measure_components
      ON measures.measure_sid = measure_components.measure_sid
      RIGHT JOIN simplified_procedural_codes
      ON measures.goods_nomenclature_item_id = simplified_procedural_codes.goods_nomenclature_item_id
      AND measures.measure_type_id = '488'
      AND measures.validity_end_date > '2021-01-01'::date
      AND measures.geographical_area_id = '1011'
      GROUP BY
        simplified_procedural_codes.simplified_procedural_code,
        measures.validity_start_date,
        measures.validity_end_date
    )

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
      # add_index :oid, unique: true # needed for concurrent view refresh
      add_index %i[depth position] # primary index
      add_index :goods_nomenclature_sid
    end
  end

  down do
    run %Q(
      DROP VIEW additional_code_description_periods;
      DROP VIEW additional_code_descriptions;
      DROP VIEW additional_code_type_descriptions;
      DROP VIEW additional_code_type_measure_types;
      DROP VIEW additional_code_types;
      DROP VIEW additional_codes;
      DROP VIEW base_regulations;
      DROP VIEW certificate_description_periods;
      DROP VIEW certificate_descriptions;
      DROP VIEW certificate_type_descriptions;
      DROP VIEW certificate_types;
      DROP VIEW certificates;
      DROP VIEW complete_abrogation_regulations;
      DROP VIEW duty_expression_descriptions;
      DROP VIEW duty_expressions;
      DROP VIEW explicit_abrogation_regulations;
      DROP VIEW export_refund_nomenclature_description_periods;
      DROP VIEW export_refund_nomenclature_descriptions;
      DROP VIEW export_refund_nomenclature_indents;
      DROP VIEW export_refund_nomenclatures;
      DROP VIEW footnote_association_additional_codes;
      DROP VIEW footnote_association_erns;
      DROP VIEW footnote_association_goods_nomenclatures;
      DROP VIEW footnote_association_measures;
      DROP VIEW footnote_association_meursing_headings;
      DROP VIEW footnote_description_periods;
      DROP VIEW footnote_descriptions;
      DROP VIEW footnote_type_descriptions;
      DROP VIEW footnote_types;
      DROP VIEW footnotes;
      DROP VIEW fts_regulation_actions;
      DROP VIEW full_temporary_stop_regulations;
      DROP VIEW geographical_area_description_periods;
      DROP VIEW geographical_area_descriptions;
      DROP VIEW geographical_area_memberships;
      DROP VIEW geographical_areas;
      DROP VIEW goods_nomenclature_description_periods;
      DROP VIEW goods_nomenclature_descriptions;
      DROP VIEW goods_nomenclature_group_descriptions;
      DROP VIEW goods_nomenclature_groups;
      DROP VIEW goods_nomenclature_indents;
      DROP VIEW goods_nomenclature_origins;
      DROP VIEW goods_nomenclature_successors;
      DROP VIEW goods_nomenclatures;
      DROP VIEW language_descriptions;
      DROP VIEW languages;
      DROP VIEW measure_action_descriptions;
      DROP VIEW measure_actions;
      DROP VIEW measure_components;
      DROP VIEW measure_condition_code_descriptions;
      DROP VIEW measure_condition_codes;
      DROP VIEW measure_condition_components;
      DROP VIEW measure_conditions;
      DROP VIEW measure_excluded_geographical_areas;
      DROP VIEW measure_partial_temporary_stops;
      DROP VIEW measure_type_descriptions;
      DROP VIEW measure_type_series;
      DROP VIEW measure_type_series_descriptions;
      DROP VIEW measure_types;
      DROP VIEW measurement_unit_descriptions;
      DROP VIEW measurement_unit_qualifier_descriptions;
      DROP VIEW measurement_unit_qualifiers;
      DROP VIEW measurement_units;
      DROP VIEW measurements;
      DROP VIEW measures;
      DROP VIEW meursing_additional_codes;
      DROP VIEW meursing_heading_texts;
      DROP VIEW meursing_headings;
      DROP VIEW meursing_subheadings;
      DROP VIEW meursing_table_cell_components;
      DROP VIEW meursing_table_plans;
      DROP VIEW modification_regulations;
      DROP VIEW monetary_exchange_periods;
      DROP VIEW monetary_exchange_rates;
      DROP VIEW monetary_unit_descriptions;
      DROP VIEW monetary_units;
      DROP VIEW nomenclature_group_memberships;
      DROP VIEW prorogation_regulation_actions;
      DROP VIEW prorogation_regulations;
      DROP VIEW publication_sigles;
      DROP VIEW quota_associations;
      DROP VIEW quota_balance_events;
      DROP VIEW quota_blocking_periods;
      DROP VIEW quota_closed_and_transferred_events;
      DROP VIEW quota_critical_events;
      DROP VIEW quota_definitions;
      DROP VIEW quota_exhaustion_events;
      DROP VIEW quota_order_number_origin_exclusions;
      DROP VIEW quota_order_number_origins;
      DROP VIEW quota_order_numbers;
      DROP VIEW quota_reopening_events;
      DROP VIEW quota_suspension_periods;
      DROP VIEW quota_unblocking_events;
      DROP VIEW quota_unsuspension_events;
      DROP VIEW regulation_group_descriptions;
      DROP VIEW regulation_groups;
      DROP VIEW regulation_replacements;
      DROP VIEW regulation_role_type_descriptions;
      DROP VIEW regulation_role_types;
      DROP VIEW transmission_comments;
      CREATE OR REPLACE VIEW additional_code_description_periods AS
        SELECT additional_code_description_periods1.additional_code_description_period_sid,
           additional_code_description_periods1.additional_code_sid,
           additional_code_description_periods1.additional_code_type_id,
           additional_code_description_periods1.additional_code,
           additional_code_description_periods1.validity_start_date,
           additional_code_description_periods1.validity_end_date,
           additional_code_description_periods1.oid,
           additional_code_description_periods1.operation,
           additional_code_description_periods1.operation_date,
           additional_code_description_periods1.filename
          FROM additional_code_description_periods_oplog additional_code_description_periods1
         WHERE ((additional_code_description_periods1.oid IN ( SELECT max(additional_code_description_periods2.oid) AS max
                  FROM additional_code_description_periods_oplog additional_code_description_periods2
                 WHERE ((additional_code_description_periods1.additional_code_description_period_sid = additional_code_description_periods2.additional_code_description_period_sid) AND (additional_code_description_periods1.additional_code_sid = additional_code_description_periods2.additional_code_sid) AND ((additional_code_description_periods1.additional_code_type_id)::text = (additional_code_description_periods2.additional_code_type_id)::text)))) AND ((additional_code_description_periods1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW additional_code_descriptions AS
        SELECT additional_code_descriptions1.additional_code_description_period_sid,
           additional_code_descriptions1.language_id,
           additional_code_descriptions1.additional_code_sid,
           additional_code_descriptions1.additional_code_type_id,
           additional_code_descriptions1.additional_code,
           additional_code_descriptions1.description,
           additional_code_descriptions1."national",
           additional_code_descriptions1.oid,
           additional_code_descriptions1.operation,
           additional_code_descriptions1.operation_date,
           additional_code_descriptions1.filename
          FROM additional_code_descriptions_oplog additional_code_descriptions1
         WHERE ((additional_code_descriptions1.oid IN ( SELECT max(additional_code_descriptions2.oid) AS max
                  FROM additional_code_descriptions_oplog additional_code_descriptions2
                 WHERE ((additional_code_descriptions1.additional_code_description_period_sid = additional_code_descriptions2.additional_code_description_period_sid) AND (additional_code_descriptions1.additional_code_sid = additional_code_descriptions2.additional_code_sid)))) AND ((additional_code_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW additional_code_type_descriptions AS
        SELECT additional_code_type_descriptions1.additional_code_type_id,
           additional_code_type_descriptions1.language_id,
           additional_code_type_descriptions1.description,
           additional_code_type_descriptions1."national",
           additional_code_type_descriptions1.oid,
           additional_code_type_descriptions1.operation,
           additional_code_type_descriptions1.operation_date,
           additional_code_type_descriptions1.filename
          FROM additional_code_type_descriptions_oplog additional_code_type_descriptions1
         WHERE ((additional_code_type_descriptions1.oid IN ( SELECT max(additional_code_type_descriptions2.oid) AS max
                  FROM additional_code_type_descriptions_oplog additional_code_type_descriptions2
                 WHERE (((additional_code_type_descriptions1.additional_code_type_id)::text = (additional_code_type_descriptions2.additional_code_type_id)::text) AND ((additional_code_type_descriptions1.language_id)::text = (additional_code_type_descriptions2.language_id)::text)))) AND ((additional_code_type_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW additional_code_type_measure_types AS
        SELECT additional_code_type_measure_types1.measure_type_id,
           additional_code_type_measure_types1.additional_code_type_id,
           additional_code_type_measure_types1.validity_start_date,
           additional_code_type_measure_types1.validity_end_date,
           additional_code_type_measure_types1."national",
           additional_code_type_measure_types1.oid,
           additional_code_type_measure_types1.operation,
           additional_code_type_measure_types1.operation_date,
           additional_code_type_measure_types1.filename
          FROM additional_code_type_measure_types_oplog additional_code_type_measure_types1
         WHERE ((additional_code_type_measure_types1.oid IN ( SELECT max(additional_code_type_measure_types2.oid) AS max
                  FROM additional_code_type_measure_types_oplog additional_code_type_measure_types2
                 WHERE (((additional_code_type_measure_types1.measure_type_id)::text = (additional_code_type_measure_types2.measure_type_id)::text) AND ((additional_code_type_measure_types1.additional_code_type_id)::text = (additional_code_type_measure_types2.additional_code_type_id)::text)))) AND ((additional_code_type_measure_types1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW additional_code_types AS
        SELECT additional_code_types1.additional_code_type_id,
           additional_code_types1.validity_start_date,
           additional_code_types1.validity_end_date,
           additional_code_types1.application_code,
           additional_code_types1.meursing_table_plan_id,
           additional_code_types1."national",
           additional_code_types1.oid,
           additional_code_types1.operation,
           additional_code_types1.operation_date,
           additional_code_types1.filename
          FROM additional_code_types_oplog additional_code_types1
         WHERE ((additional_code_types1.oid IN ( SELECT max(additional_code_types2.oid) AS max
                  FROM additional_code_types_oplog additional_code_types2
                 WHERE ((additional_code_types1.additional_code_type_id)::text = (additional_code_types2.additional_code_type_id)::text))) AND ((additional_code_types1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW additional_codes AS
        SELECT additional_codes1.additional_code_sid,
           additional_codes1.additional_code_type_id,
           additional_codes1.additional_code,
           additional_codes1.validity_start_date,
           additional_codes1.validity_end_date,
           additional_codes1."national",
           additional_codes1.oid,
           additional_codes1.operation,
           additional_codes1.operation_date,
           additional_codes1.filename
          FROM additional_codes_oplog additional_codes1
         WHERE ((additional_codes1.oid IN ( SELECT max(additional_codes2.oid) AS max
                  FROM additional_codes_oplog additional_codes2
                 WHERE (additional_codes1.additional_code_sid = additional_codes2.additional_code_sid))) AND ((additional_codes1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW base_regulations AS
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
         WHERE ((base_regulations1.oid IN ( SELECT max(base_regulations2.oid) AS max
                  FROM base_regulations_oplog base_regulations2
                 WHERE (((base_regulations1.base_regulation_id)::text = (base_regulations2.base_regulation_id)::text) AND (base_regulations1.base_regulation_role = base_regulations2.base_regulation_role)))) AND ((base_regulations1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW certificate_description_periods AS
        SELECT certificate_description_periods1.certificate_description_period_sid,
           certificate_description_periods1.certificate_type_code,
           certificate_description_periods1.certificate_code,
           certificate_description_periods1.validity_start_date,
           certificate_description_periods1.validity_end_date,
           certificate_description_periods1."national",
           certificate_description_periods1.oid,
           certificate_description_periods1.operation,
           certificate_description_periods1.operation_date,
           certificate_description_periods1.filename
          FROM certificate_description_periods_oplog certificate_description_periods1
         WHERE ((certificate_description_periods1.oid IN ( SELECT max(certificate_description_periods2.oid) AS max
                  FROM certificate_description_periods_oplog certificate_description_periods2
                 WHERE (certificate_description_periods1.certificate_description_period_sid = certificate_description_periods2.certificate_description_period_sid))) AND ((certificate_description_periods1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW certificate_descriptions AS
        SELECT certificate_descriptions1.certificate_description_period_sid,
           certificate_descriptions1.language_id,
           certificate_descriptions1.certificate_type_code,
           certificate_descriptions1.certificate_code,
           certificate_descriptions1.description,
           certificate_descriptions1."national",
           certificate_descriptions1.oid,
           certificate_descriptions1.operation,
           certificate_descriptions1.operation_date,
           certificate_descriptions1.filename
          FROM certificate_descriptions_oplog certificate_descriptions1
         WHERE ((certificate_descriptions1.oid IN ( SELECT max(certificate_descriptions2.oid) AS max
                  FROM certificate_descriptions_oplog certificate_descriptions2
                 WHERE (certificate_descriptions1.certificate_description_period_sid = certificate_descriptions2.certificate_description_period_sid))) AND ((certificate_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW certificate_type_descriptions AS
        SELECT certificate_type_descriptions1.certificate_type_code,
           certificate_type_descriptions1.language_id,
           certificate_type_descriptions1.description,
           certificate_type_descriptions1."national",
           certificate_type_descriptions1.oid,
           certificate_type_descriptions1.operation,
           certificate_type_descriptions1.operation_date,
           certificate_type_descriptions1.filename
          FROM certificate_type_descriptions_oplog certificate_type_descriptions1
         WHERE ((certificate_type_descriptions1.oid IN ( SELECT max(certificate_type_descriptions2.oid) AS max
                  FROM certificate_type_descriptions_oplog certificate_type_descriptions2
                 WHERE ((certificate_type_descriptions1.certificate_type_code)::text = (certificate_type_descriptions2.certificate_type_code)::text))) AND ((certificate_type_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW certificate_types AS
        SELECT certificate_types1.certificate_type_code,
           certificate_types1.validity_start_date,
           certificate_types1.validity_end_date,
           certificate_types1."national",
           certificate_types1.oid,
           certificate_types1.operation,
           certificate_types1.operation_date,
           certificate_types1.filename
          FROM certificate_types_oplog certificate_types1
         WHERE ((certificate_types1.oid IN ( SELECT max(certificate_types2.oid) AS max
                  FROM certificate_types_oplog certificate_types2
                 WHERE ((certificate_types1.certificate_type_code)::text = (certificate_types2.certificate_type_code)::text))) AND ((certificate_types1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW certificates AS
        SELECT certificates1.certificate_type_code,
           certificates1.certificate_code,
           certificates1.validity_start_date,
           certificates1.validity_end_date,
           certificates1."national",
           certificates1.national_abbrev,
           certificates1.oid,
           certificates1.operation,
           certificates1.operation_date,
           certificates1.filename
          FROM certificates_oplog certificates1
         WHERE ((certificates1.oid IN ( SELECT max(certificates2.oid) AS max
                  FROM certificates_oplog certificates2
                 WHERE (((certificates1.certificate_code)::text = (certificates2.certificate_code)::text) AND ((certificates1.certificate_type_code)::text = (certificates2.certificate_type_code)::text)))) AND ((certificates1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW complete_abrogation_regulations AS
        SELECT complete_abrogation_regulations1.complete_abrogation_regulation_role,
           complete_abrogation_regulations1.complete_abrogation_regulation_id,
           complete_abrogation_regulations1.published_date,
           complete_abrogation_regulations1.officialjournal_number,
           complete_abrogation_regulations1.officialjournal_page,
           complete_abrogation_regulations1.replacement_indicator,
           complete_abrogation_regulations1.information_text,
           complete_abrogation_regulations1.approved_flag,
           complete_abrogation_regulations1.oid,
           complete_abrogation_regulations1.operation,
           complete_abrogation_regulations1.operation_date,
           complete_abrogation_regulations1.filename
          FROM complete_abrogation_regulations_oplog complete_abrogation_regulations1
         WHERE ((complete_abrogation_regulations1.oid IN ( SELECT max(complete_abrogation_regulations2.oid) AS max
                  FROM complete_abrogation_regulations_oplog complete_abrogation_regulations2
                 WHERE (((complete_abrogation_regulations1.complete_abrogation_regulation_id)::text = (complete_abrogation_regulations2.complete_abrogation_regulation_id)::text) AND (complete_abrogation_regulations1.complete_abrogation_regulation_role = complete_abrogation_regulations2.complete_abrogation_regulation_role)))) AND ((complete_abrogation_regulations1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW duty_expression_descriptions AS
        SELECT duty_expression_descriptions1.duty_expression_id,
           duty_expression_descriptions1.language_id,
           duty_expression_descriptions1.description,
           duty_expression_descriptions1.oid,
           duty_expression_descriptions1.operation,
           duty_expression_descriptions1.operation_date,
           duty_expression_descriptions1.filename
          FROM duty_expression_descriptions_oplog duty_expression_descriptions1
         WHERE ((duty_expression_descriptions1.oid IN ( SELECT max(duty_expression_descriptions2.oid) AS max
                  FROM duty_expression_descriptions_oplog duty_expression_descriptions2
                 WHERE ((duty_expression_descriptions1.duty_expression_id)::text = (duty_expression_descriptions2.duty_expression_id)::text))) AND ((duty_expression_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW duty_expressions AS
        SELECT duty_expressions1.duty_expression_id,
           duty_expressions1.validity_start_date,
           duty_expressions1.validity_end_date,
           duty_expressions1.duty_amount_applicability_code,
           duty_expressions1.measurement_unit_applicability_code,
           duty_expressions1.monetary_unit_applicability_code,
           duty_expressions1.oid,
           duty_expressions1.operation,
           duty_expressions1.operation_date,
           duty_expressions1.filename
          FROM duty_expressions_oplog duty_expressions1
         WHERE ((duty_expressions1.oid IN ( SELECT max(duty_expressions2.oid) AS max
                  FROM duty_expressions_oplog duty_expressions2
                 WHERE ((duty_expressions1.duty_expression_id)::text = (duty_expressions2.duty_expression_id)::text))) AND ((duty_expressions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW explicit_abrogation_regulations AS
        SELECT explicit_abrogation_regulations1.explicit_abrogation_regulation_role,
           explicit_abrogation_regulations1.explicit_abrogation_regulation_id,
           explicit_abrogation_regulations1.published_date,
           explicit_abrogation_regulations1.officialjournal_number,
           explicit_abrogation_regulations1.officialjournal_page,
           explicit_abrogation_regulations1.replacement_indicator,
           explicit_abrogation_regulations1.abrogation_date,
           explicit_abrogation_regulations1.information_text,
           explicit_abrogation_regulations1.approved_flag,
           explicit_abrogation_regulations1.oid,
           explicit_abrogation_regulations1.operation,
           explicit_abrogation_regulations1.operation_date,
           explicit_abrogation_regulations1.filename
          FROM explicit_abrogation_regulations_oplog explicit_abrogation_regulations1
         WHERE ((explicit_abrogation_regulations1.oid IN ( SELECT max(explicit_abrogation_regulations2.oid) AS max
                  FROM explicit_abrogation_regulations_oplog explicit_abrogation_regulations2
                 WHERE (((explicit_abrogation_regulations1.explicit_abrogation_regulation_id)::text = (explicit_abrogation_regulations2.explicit_abrogation_regulation_id)::text) AND (explicit_abrogation_regulations1.explicit_abrogation_regulation_role = explicit_abrogation_regulations2.explicit_abrogation_regulation_role)))) AND ((explicit_abrogation_regulations1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW export_refund_nomenclature_description_periods AS
        SELECT export_refund_nomenclature_description_periods1.export_refund_nomenclature_description_period_sid,
           export_refund_nomenclature_description_periods1.export_refund_nomenclature_sid,
           export_refund_nomenclature_description_periods1.validity_start_date,
           export_refund_nomenclature_description_periods1.goods_nomenclature_item_id,
           export_refund_nomenclature_description_periods1.additional_code_type,
           export_refund_nomenclature_description_periods1.export_refund_code,
           export_refund_nomenclature_description_periods1.productline_suffix,
           export_refund_nomenclature_description_periods1.validity_end_date,
           export_refund_nomenclature_description_periods1.oid,
           export_refund_nomenclature_description_periods1.operation,
           export_refund_nomenclature_description_periods1.operation_date,
           export_refund_nomenclature_description_periods1.filename
          FROM export_refund_nomenclature_description_periods_oplog export_refund_nomenclature_description_periods1
         WHERE ((export_refund_nomenclature_description_periods1.oid IN ( SELECT max(export_refund_nomenclature_description_periods2.oid) AS max
                  FROM export_refund_nomenclature_description_periods_oplog export_refund_nomenclature_description_periods2
                 WHERE ((export_refund_nomenclature_description_periods1.export_refund_nomenclature_sid = export_refund_nomenclature_description_periods2.export_refund_nomenclature_sid) AND (export_refund_nomenclature_description_periods1.export_refund_nomenclature_description_period_sid = export_refund_nomenclature_description_periods2.export_refund_nomenclature_description_period_sid)))) AND ((export_refund_nomenclature_description_periods1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW export_refund_nomenclature_descriptions AS
        SELECT export_refund_nomenclature_descriptions1.export_refund_nomenclature_description_period_sid,
           export_refund_nomenclature_descriptions1.language_id,
           export_refund_nomenclature_descriptions1.export_refund_nomenclature_sid,
           export_refund_nomenclature_descriptions1.goods_nomenclature_item_id,
           export_refund_nomenclature_descriptions1.additional_code_type,
           export_refund_nomenclature_descriptions1.export_refund_code,
           export_refund_nomenclature_descriptions1.productline_suffix,
           export_refund_nomenclature_descriptions1.description,
           export_refund_nomenclature_descriptions1.oid,
           export_refund_nomenclature_descriptions1.operation,
           export_refund_nomenclature_descriptions1.operation_date,
           export_refund_nomenclature_descriptions1.filename
          FROM export_refund_nomenclature_descriptions_oplog export_refund_nomenclature_descriptions1
         WHERE ((export_refund_nomenclature_descriptions1.oid IN ( SELECT max(export_refund_nomenclature_descriptions2.oid) AS max
                  FROM export_refund_nomenclature_descriptions_oplog export_refund_nomenclature_descriptions2
                 WHERE (export_refund_nomenclature_descriptions1.export_refund_nomenclature_description_period_sid = export_refund_nomenclature_descriptions2.export_refund_nomenclature_description_period_sid))) AND ((export_refund_nomenclature_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW export_refund_nomenclature_indents AS
        SELECT export_refund_nomenclature_indents1.export_refund_nomenclature_indents_sid,
           export_refund_nomenclature_indents1.export_refund_nomenclature_sid,
           export_refund_nomenclature_indents1.validity_start_date,
           export_refund_nomenclature_indents1.number_export_refund_nomenclature_indents,
           export_refund_nomenclature_indents1.goods_nomenclature_item_id,
           export_refund_nomenclature_indents1.additional_code_type,
           export_refund_nomenclature_indents1.export_refund_code,
           export_refund_nomenclature_indents1.productline_suffix,
           export_refund_nomenclature_indents1.validity_end_date,
           export_refund_nomenclature_indents1.oid,
           export_refund_nomenclature_indents1.operation,
           export_refund_nomenclature_indents1.operation_date,
           export_refund_nomenclature_indents1.filename
          FROM export_refund_nomenclature_indents_oplog export_refund_nomenclature_indents1
         WHERE ((export_refund_nomenclature_indents1.oid IN ( SELECT max(export_refund_nomenclature_indents2.oid) AS max
                  FROM export_refund_nomenclature_indents_oplog export_refund_nomenclature_indents2
                 WHERE (export_refund_nomenclature_indents1.export_refund_nomenclature_indents_sid = export_refund_nomenclature_indents2.export_refund_nomenclature_indents_sid))) AND ((export_refund_nomenclature_indents1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW export_refund_nomenclatures AS
        SELECT export_refund_nomenclatures1.export_refund_nomenclature_sid,
           export_refund_nomenclatures1.goods_nomenclature_item_id,
           export_refund_nomenclatures1.additional_code_type,
           export_refund_nomenclatures1.export_refund_code,
           export_refund_nomenclatures1.productline_suffix,
           export_refund_nomenclatures1.validity_start_date,
           export_refund_nomenclatures1.validity_end_date,
           export_refund_nomenclatures1.goods_nomenclature_sid,
           export_refund_nomenclatures1.oid,
           export_refund_nomenclatures1.operation,
           export_refund_nomenclatures1.operation_date,
           export_refund_nomenclatures1.filename
          FROM export_refund_nomenclatures_oplog export_refund_nomenclatures1
         WHERE ((export_refund_nomenclatures1.oid IN ( SELECT max(export_refund_nomenclatures2.oid) AS max
                  FROM export_refund_nomenclatures_oplog export_refund_nomenclatures2
                 WHERE (export_refund_nomenclatures1.export_refund_nomenclature_sid = export_refund_nomenclatures2.export_refund_nomenclature_sid))) AND ((export_refund_nomenclatures1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW footnote_association_additional_codes AS
        SELECT footnote_association_additional_codes1.additional_code_sid,
           footnote_association_additional_codes1.footnote_type_id,
           footnote_association_additional_codes1.footnote_id,
           footnote_association_additional_codes1.validity_start_date,
           footnote_association_additional_codes1.validity_end_date,
           footnote_association_additional_codes1.additional_code_type_id,
           footnote_association_additional_codes1.additional_code,
           footnote_association_additional_codes1.oid,
           footnote_association_additional_codes1.operation,
           footnote_association_additional_codes1.operation_date,
           footnote_association_additional_codes1.filename
          FROM footnote_association_additional_codes_oplog footnote_association_additional_codes1
         WHERE ((footnote_association_additional_codes1.oid IN ( SELECT max(footnote_association_additional_codes2.oid) AS max
                  FROM footnote_association_additional_codes_oplog footnote_association_additional_codes2
                 WHERE (((footnote_association_additional_codes1.footnote_id)::text = (footnote_association_additional_codes2.footnote_id)::text) AND ((footnote_association_additional_codes1.footnote_type_id)::text = (footnote_association_additional_codes2.footnote_type_id)::text) AND (footnote_association_additional_codes1.additional_code_sid = footnote_association_additional_codes2.additional_code_sid)))) AND ((footnote_association_additional_codes1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW footnote_association_erns AS
        SELECT footnote_association_erns1.export_refund_nomenclature_sid,
           footnote_association_erns1.footnote_type,
           footnote_association_erns1.footnote_id,
           footnote_association_erns1.validity_start_date,
           footnote_association_erns1.validity_end_date,
           footnote_association_erns1.goods_nomenclature_item_id,
           footnote_association_erns1.additional_code_type,
           footnote_association_erns1.export_refund_code,
           footnote_association_erns1.productline_suffix,
           footnote_association_erns1.oid,
           footnote_association_erns1.operation,
           footnote_association_erns1.operation_date,
           footnote_association_erns1.filename
          FROM footnote_association_erns_oplog footnote_association_erns1
         WHERE ((footnote_association_erns1.oid IN ( SELECT max(footnote_association_erns2.oid) AS max
                  FROM footnote_association_erns_oplog footnote_association_erns2
                 WHERE ((footnote_association_erns1.export_refund_nomenclature_sid = footnote_association_erns2.export_refund_nomenclature_sid) AND ((footnote_association_erns1.footnote_id)::text = (footnote_association_erns2.footnote_id)::text) AND ((footnote_association_erns1.footnote_type)::text = (footnote_association_erns2.footnote_type)::text) AND (footnote_association_erns1.validity_start_date = footnote_association_erns2.validity_start_date)))) AND ((footnote_association_erns1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW footnote_association_goods_nomenclatures AS
        SELECT footnote_association_goods_nomenclatures1.goods_nomenclature_sid,
           footnote_association_goods_nomenclatures1.footnote_type,
           footnote_association_goods_nomenclatures1.footnote_id,
           footnote_association_goods_nomenclatures1.validity_start_date,
           footnote_association_goods_nomenclatures1.validity_end_date,
           footnote_association_goods_nomenclatures1.goods_nomenclature_item_id,
           footnote_association_goods_nomenclatures1.productline_suffix,
           footnote_association_goods_nomenclatures1."national",
           footnote_association_goods_nomenclatures1.oid,
           footnote_association_goods_nomenclatures1.operation,
           footnote_association_goods_nomenclatures1.operation_date,
           footnote_association_goods_nomenclatures1.filename
          FROM footnote_association_goods_nomenclatures_oplog footnote_association_goods_nomenclatures1
         WHERE ((footnote_association_goods_nomenclatures1.oid IN ( SELECT max(footnote_association_goods_nomenclatures2.oid) AS max
                  FROM footnote_association_goods_nomenclatures_oplog footnote_association_goods_nomenclatures2
                 WHERE (((footnote_association_goods_nomenclatures1.footnote_id)::text = (footnote_association_goods_nomenclatures2.footnote_id)::text) AND ((footnote_association_goods_nomenclatures1.footnote_type)::text = (footnote_association_goods_nomenclatures2.footnote_type)::text) AND (footnote_association_goods_nomenclatures1.goods_nomenclature_sid = footnote_association_goods_nomenclatures2.goods_nomenclature_sid)))) AND ((footnote_association_goods_nomenclatures1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW footnote_association_measures AS
        SELECT footnote_association_measures1.measure_sid,
           footnote_association_measures1.footnote_type_id,
           footnote_association_measures1.footnote_id,
           footnote_association_measures1."national",
           footnote_association_measures1.oid,
           footnote_association_measures1.operation,
           footnote_association_measures1.operation_date,
           footnote_association_measures1.filename
          FROM footnote_association_measures_oplog footnote_association_measures1
         WHERE ((footnote_association_measures1.oid IN ( SELECT max(footnote_association_measures2.oid) AS max
                  FROM footnote_association_measures_oplog footnote_association_measures2
                 WHERE ((footnote_association_measures1.measure_sid = footnote_association_measures2.measure_sid) AND ((footnote_association_measures1.footnote_id)::text = (footnote_association_measures2.footnote_id)::text) AND ((footnote_association_measures1.footnote_type_id)::text = (footnote_association_measures2.footnote_type_id)::text)))) AND ((footnote_association_measures1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW footnote_association_meursing_headings AS
        SELECT footnote_association_meursing_headings1.meursing_table_plan_id,
           footnote_association_meursing_headings1.meursing_heading_number,
           footnote_association_meursing_headings1.row_column_code,
           footnote_association_meursing_headings1.footnote_type,
           footnote_association_meursing_headings1.footnote_id,
           footnote_association_meursing_headings1.validity_start_date,
           footnote_association_meursing_headings1.validity_end_date,
           footnote_association_meursing_headings1.oid,
           footnote_association_meursing_headings1.operation,
           footnote_association_meursing_headings1.operation_date,
           footnote_association_meursing_headings1.filename
          FROM footnote_association_meursing_headings_oplog footnote_association_meursing_headings1
         WHERE ((footnote_association_meursing_headings1.oid IN ( SELECT max(footnote_association_meursing_headings2.oid) AS max
                  FROM footnote_association_meursing_headings_oplog footnote_association_meursing_headings2
                 WHERE (((footnote_association_meursing_headings1.footnote_id)::text = (footnote_association_meursing_headings2.footnote_id)::text) AND ((footnote_association_meursing_headings1.meursing_table_plan_id)::text = (footnote_association_meursing_headings2.meursing_table_plan_id)::text)))) AND ((footnote_association_meursing_headings1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW footnote_description_periods AS
        SELECT footnote_description_periods1.footnote_description_period_sid,
           footnote_description_periods1.footnote_type_id,
           footnote_description_periods1.footnote_id,
           footnote_description_periods1.validity_start_date,
           footnote_description_periods1.validity_end_date,
           footnote_description_periods1."national",
           footnote_description_periods1.oid,
           footnote_description_periods1.operation,
           footnote_description_periods1.operation_date,
           footnote_description_periods1.filename
          FROM footnote_description_periods_oplog footnote_description_periods1
         WHERE ((footnote_description_periods1.oid IN ( SELECT max(footnote_description_periods2.oid) AS max
                  FROM footnote_description_periods_oplog footnote_description_periods2
                 WHERE (((footnote_description_periods1.footnote_id)::text = (footnote_description_periods2.footnote_id)::text) AND ((footnote_description_periods1.footnote_type_id)::text = (footnote_description_periods2.footnote_type_id)::text) AND (footnote_description_periods1.footnote_description_period_sid = footnote_description_periods2.footnote_description_period_sid)))) AND ((footnote_description_periods1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW footnote_descriptions AS
        SELECT footnote_descriptions1.footnote_description_period_sid,
           footnote_descriptions1.footnote_type_id,
           footnote_descriptions1.footnote_id,
           footnote_descriptions1.language_id,
           footnote_descriptions1.description,
           footnote_descriptions1."national",
           footnote_descriptions1.oid,
           footnote_descriptions1.operation,
           footnote_descriptions1.operation_date,
           footnote_descriptions1.filename
          FROM footnote_descriptions_oplog footnote_descriptions1
         WHERE ((footnote_descriptions1.oid IN ( SELECT max(footnote_descriptions2.oid) AS max
                  FROM footnote_descriptions_oplog footnote_descriptions2
                 WHERE ((footnote_descriptions1.footnote_description_period_sid = footnote_descriptions2.footnote_description_period_sid) AND ((footnote_descriptions1.footnote_id)::text = (footnote_descriptions2.footnote_id)::text) AND ((footnote_descriptions1.footnote_type_id)::text = (footnote_descriptions2.footnote_type_id)::text)))) AND ((footnote_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW footnote_type_descriptions AS
        SELECT footnote_type_descriptions1.footnote_type_id,
           footnote_type_descriptions1.language_id,
           footnote_type_descriptions1.description,
           footnote_type_descriptions1."national",
           footnote_type_descriptions1.oid,
           footnote_type_descriptions1.operation,
           footnote_type_descriptions1.operation_date,
           footnote_type_descriptions1.filename
          FROM footnote_type_descriptions_oplog footnote_type_descriptions1
         WHERE ((footnote_type_descriptions1.oid IN ( SELECT max(footnote_type_descriptions2.oid) AS max
                  FROM footnote_type_descriptions_oplog footnote_type_descriptions2
                 WHERE ((footnote_type_descriptions1.footnote_type_id)::text = (footnote_type_descriptions2.footnote_type_id)::text))) AND ((footnote_type_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW footnote_types AS
        SELECT footnote_types1.footnote_type_id,
           footnote_types1.application_code,
           footnote_types1.validity_start_date,
           footnote_types1.validity_end_date,
           footnote_types1."national",
           footnote_types1.oid,
           footnote_types1.operation,
           footnote_types1.operation_date,
           footnote_types1.filename
          FROM footnote_types_oplog footnote_types1
         WHERE ((footnote_types1.oid IN ( SELECT max(footnote_types2.oid) AS max
                  FROM footnote_types_oplog footnote_types2
                 WHERE ((footnote_types1.footnote_type_id)::text = (footnote_types2.footnote_type_id)::text))) AND ((footnote_types1.operation)::text <> 'D'::text));

      CREATE VIEW footnotes AS
        SELECT footnotes1.footnote_id,
           footnotes1.footnote_type_id,
           footnotes1.validity_start_date,
           footnotes1.validity_end_date,
           footnotes1."national",
           footnotes1.oid,
           footnotes1.operation,
           footnotes1.operation_date,
           footnotes1.filename
          FROM footnotes_oplog footnotes1
         WHERE ((footnotes1.oid IN ( SELECT max(footnotes2.oid) AS max
                  FROM footnotes_oplog footnotes2
                 WHERE (((footnotes1.footnote_type_id)::text = (footnotes2.footnote_type_id)::text) AND ((footnotes1.footnote_id)::text = (footnotes2.footnote_id)::text)))) AND ((footnotes1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW fts_regulation_actions AS
        SELECT fts_regulation_actions1.fts_regulation_role,
           fts_regulation_actions1.fts_regulation_id,
           fts_regulation_actions1.stopped_regulation_role,
           fts_regulation_actions1.stopped_regulation_id,
           fts_regulation_actions1.oid,
           fts_regulation_actions1.operation,
           fts_regulation_actions1.operation_date,
           fts_regulation_actions1.filename
          FROM fts_regulation_actions_oplog fts_regulation_actions1
         WHERE ((fts_regulation_actions1.oid IN ( SELECT max(fts_regulation_actions2.oid) AS max
                  FROM fts_regulation_actions_oplog fts_regulation_actions2
                 WHERE (((fts_regulation_actions1.fts_regulation_id)::text = (fts_regulation_actions2.fts_regulation_id)::text) AND (fts_regulation_actions1.fts_regulation_role = fts_regulation_actions2.fts_regulation_role) AND ((fts_regulation_actions1.stopped_regulation_id)::text = (fts_regulation_actions2.stopped_regulation_id)::text) AND (fts_regulation_actions1.stopped_regulation_role = fts_regulation_actions2.stopped_regulation_role)))) AND ((fts_regulation_actions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW full_temporary_stop_regulations AS
        SELECT full_temporary_stop_regulations1.full_temporary_stop_regulation_role,
           full_temporary_stop_regulations1.full_temporary_stop_regulation_id,
           full_temporary_stop_regulations1.published_date,
           full_temporary_stop_regulations1.officialjournal_number,
           full_temporary_stop_regulations1.officialjournal_page,
           full_temporary_stop_regulations1.validity_start_date,
           full_temporary_stop_regulations1.validity_end_date,
           full_temporary_stop_regulations1.effective_enddate,
           full_temporary_stop_regulations1.explicit_abrogation_regulation_role,
           full_temporary_stop_regulations1.explicit_abrogation_regulation_id,
           full_temporary_stop_regulations1.replacement_indicator,
           full_temporary_stop_regulations1.information_text,
           full_temporary_stop_regulations1.approved_flag,
           full_temporary_stop_regulations1.oid,
           full_temporary_stop_regulations1.operation,
           full_temporary_stop_regulations1.operation_date,
           full_temporary_stop_regulations1.complete_abrogation_regulation_role,
           full_temporary_stop_regulations1.complete_abrogation_regulation_id,
           full_temporary_stop_regulations1.filename
          FROM full_temporary_stop_regulations_oplog full_temporary_stop_regulations1
         WHERE ((full_temporary_stop_regulations1.oid IN ( SELECT max(full_temporary_stop_regulations2.oid) AS max
                  FROM full_temporary_stop_regulations_oplog full_temporary_stop_regulations2
                 WHERE (((full_temporary_stop_regulations1.full_temporary_stop_regulation_id)::text = (full_temporary_stop_regulations2.full_temporary_stop_regulation_id)::text) AND (full_temporary_stop_regulations1.full_temporary_stop_regulation_role = full_temporary_stop_regulations2.full_temporary_stop_regulation_role)))) AND ((full_temporary_stop_regulations1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW geographical_area_description_periods AS
        SELECT geographical_area_description_periods1.geographical_area_description_period_sid,
           geographical_area_description_periods1.geographical_area_sid,
           geographical_area_description_periods1.validity_start_date,
           geographical_area_description_periods1.geographical_area_id,
           geographical_area_description_periods1.validity_end_date,
           geographical_area_description_periods1."national",
           geographical_area_description_periods1.oid,
           geographical_area_description_periods1.operation,
           geographical_area_description_periods1.operation_date,
           geographical_area_description_periods1.filename
          FROM geographical_area_description_periods_oplog geographical_area_description_periods1
         WHERE ((geographical_area_description_periods1.oid IN ( SELECT max(geographical_area_description_periods2.oid) AS max
                  FROM geographical_area_description_periods_oplog geographical_area_description_periods2
                 WHERE ((geographical_area_description_periods1.geographical_area_description_period_sid = geographical_area_description_periods2.geographical_area_description_period_sid) AND (geographical_area_description_periods1.geographical_area_sid = geographical_area_description_periods2.geographical_area_sid)))) AND ((geographical_area_description_periods1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW geographical_area_descriptions AS
        SELECT geographical_area_descriptions1.geographical_area_description_period_sid,
           geographical_area_descriptions1.language_id,
           geographical_area_descriptions1.geographical_area_sid,
           geographical_area_descriptions1.geographical_area_id,
           geographical_area_descriptions1.description,
           geographical_area_descriptions1."national",
           geographical_area_descriptions1.oid,
           geographical_area_descriptions1.operation,
           geographical_area_descriptions1.operation_date,
           geographical_area_descriptions1.filename
          FROM geographical_area_descriptions_oplog geographical_area_descriptions1
         WHERE ((geographical_area_descriptions1.oid IN ( SELECT max(geographical_area_descriptions2.oid) AS max
                  FROM geographical_area_descriptions_oplog geographical_area_descriptions2
                 WHERE ((geographical_area_descriptions1.geographical_area_description_period_sid = geographical_area_descriptions2.geographical_area_description_period_sid) AND (geographical_area_descriptions1.geographical_area_sid = geographical_area_descriptions2.geographical_area_sid)))) AND ((geographical_area_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW geographical_area_memberships AS
        SELECT geographical_area_memberships1.geographical_area_sid,
           geographical_area_memberships1.geographical_area_group_sid,
           geographical_area_memberships1.validity_start_date,
           geographical_area_memberships1.validity_end_date,
           geographical_area_memberships1."national",
           geographical_area_memberships1.oid,
           geographical_area_memberships1.operation,
           geographical_area_memberships1.operation_date,
           geographical_area_memberships1.filename,
           geographical_area_memberships1.hjid,
           geographical_area_memberships1.geographical_area_hjid,
           geographical_area_memberships1.geographical_area_group_hjid
          FROM geographical_area_memberships_oplog geographical_area_memberships1
         WHERE ((geographical_area_memberships1.oid IN ( SELECT max(geographical_area_memberships2.oid) AS max
                  FROM geographical_area_memberships_oplog geographical_area_memberships2
                 WHERE ((geographical_area_memberships1.geographical_area_sid = geographical_area_memberships2.geographical_area_sid) AND (geographical_area_memberships1.geographical_area_group_sid = geographical_area_memberships2.geographical_area_group_sid) AND (geographical_area_memberships1.validity_start_date = geographical_area_memberships2.validity_start_date)))) AND ((geographical_area_memberships1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW geographical_areas AS
        SELECT geographical_areas1.geographical_area_sid,
           geographical_areas1.parent_geographical_area_group_sid,
           geographical_areas1.validity_start_date,
           geographical_areas1.validity_end_date,
           geographical_areas1.geographical_code,
           geographical_areas1.geographical_area_id,
           geographical_areas1."national",
           geographical_areas1.oid,
           geographical_areas1.operation,
           geographical_areas1.operation_date,
           geographical_areas1.filename,
           geographical_areas1.hjid
          FROM geographical_areas_oplog geographical_areas1
         WHERE ((geographical_areas1.oid IN ( SELECT max(geographical_areas2.oid) AS max
                  FROM geographical_areas_oplog geographical_areas2
                 WHERE (geographical_areas1.geographical_area_sid = geographical_areas2.geographical_area_sid))) AND ((geographical_areas1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW goods_nomenclature_description_periods AS
        SELECT goods_nomenclature_description_periods1.goods_nomenclature_description_period_sid,
           goods_nomenclature_description_periods1.goods_nomenclature_sid,
           goods_nomenclature_description_periods1.validity_start_date,
           goods_nomenclature_description_periods1.goods_nomenclature_item_id,
           goods_nomenclature_description_periods1.productline_suffix,
           goods_nomenclature_description_periods1.validity_end_date,
           goods_nomenclature_description_periods1.oid,
           goods_nomenclature_description_periods1.operation,
           goods_nomenclature_description_periods1.operation_date,
           goods_nomenclature_description_periods1.filename
          FROM goods_nomenclature_description_periods_oplog goods_nomenclature_description_periods1
         WHERE ((goods_nomenclature_description_periods1.oid IN ( SELECT max(goods_nomenclature_description_periods2.oid) AS max
                  FROM goods_nomenclature_description_periods_oplog goods_nomenclature_description_periods2
                 WHERE (goods_nomenclature_description_periods1.goods_nomenclature_description_period_sid = goods_nomenclature_description_periods2.goods_nomenclature_description_period_sid))) AND ((goods_nomenclature_description_periods1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW goods_nomenclature_descriptions AS
        SELECT goods_nomenclature_descriptions1.goods_nomenclature_description_period_sid,
           goods_nomenclature_descriptions1.language_id,
           goods_nomenclature_descriptions1.goods_nomenclature_sid,
           goods_nomenclature_descriptions1.goods_nomenclature_item_id,
           goods_nomenclature_descriptions1.productline_suffix,
           goods_nomenclature_descriptions1.description,
           goods_nomenclature_descriptions1.oid,
           goods_nomenclature_descriptions1.operation,
           goods_nomenclature_descriptions1.operation_date,
           goods_nomenclature_descriptions1.filename
          FROM goods_nomenclature_descriptions_oplog goods_nomenclature_descriptions1
         WHERE ((goods_nomenclature_descriptions1.oid IN ( SELECT max(goods_nomenclature_descriptions2.oid) AS max
                  FROM goods_nomenclature_descriptions_oplog goods_nomenclature_descriptions2
                 WHERE ((goods_nomenclature_descriptions1.goods_nomenclature_sid = goods_nomenclature_descriptions2.goods_nomenclature_sid) AND (goods_nomenclature_descriptions1.goods_nomenclature_description_period_sid = goods_nomenclature_descriptions2.goods_nomenclature_description_period_sid)))) AND ((goods_nomenclature_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW goods_nomenclature_group_descriptions AS
        SELECT goods_nomenclature_group_descriptions1.goods_nomenclature_group_type,
           goods_nomenclature_group_descriptions1.goods_nomenclature_group_id,
           goods_nomenclature_group_descriptions1.language_id,
           goods_nomenclature_group_descriptions1.description,
           goods_nomenclature_group_descriptions1.oid,
           goods_nomenclature_group_descriptions1.operation,
           goods_nomenclature_group_descriptions1.operation_date,
           goods_nomenclature_group_descriptions1.filename
          FROM goods_nomenclature_group_descriptions_oplog goods_nomenclature_group_descriptions1
         WHERE ((goods_nomenclature_group_descriptions1.oid IN ( SELECT max(goods_nomenclature_group_descriptions2.oid) AS max
                  FROM goods_nomenclature_group_descriptions_oplog goods_nomenclature_group_descriptions2
                 WHERE (((goods_nomenclature_group_descriptions1.goods_nomenclature_group_id)::text = (goods_nomenclature_group_descriptions2.goods_nomenclature_group_id)::text) AND ((goods_nomenclature_group_descriptions1.goods_nomenclature_group_type)::text = (goods_nomenclature_group_descriptions2.goods_nomenclature_group_type)::text)))) AND ((goods_nomenclature_group_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW goods_nomenclature_groups AS
        SELECT goods_nomenclature_groups1.goods_nomenclature_group_type,
           goods_nomenclature_groups1.goods_nomenclature_group_id,
           goods_nomenclature_groups1.validity_start_date,
           goods_nomenclature_groups1.validity_end_date,
           goods_nomenclature_groups1.nomenclature_group_facility_code,
           goods_nomenclature_groups1.oid,
           goods_nomenclature_groups1.operation,
           goods_nomenclature_groups1.operation_date,
           goods_nomenclature_groups1.filename
          FROM goods_nomenclature_groups_oplog goods_nomenclature_groups1
         WHERE ((goods_nomenclature_groups1.oid IN ( SELECT max(goods_nomenclature_groups2.oid) AS max
                  FROM goods_nomenclature_groups_oplog goods_nomenclature_groups2
                 WHERE (((goods_nomenclature_groups1.goods_nomenclature_group_id)::text = (goods_nomenclature_groups2.goods_nomenclature_group_id)::text) AND ((goods_nomenclature_groups1.goods_nomenclature_group_type)::text = (goods_nomenclature_groups2.goods_nomenclature_group_type)::text)))) AND ((goods_nomenclature_groups1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW goods_nomenclature_indents AS
        SELECT goods_nomenclature_indents1.goods_nomenclature_indent_sid,
           goods_nomenclature_indents1.goods_nomenclature_sid,
           goods_nomenclature_indents1.validity_start_date,
           goods_nomenclature_indents1.number_indents,
           goods_nomenclature_indents1.goods_nomenclature_item_id,
           goods_nomenclature_indents1.productline_suffix,
           goods_nomenclature_indents1.validity_end_date,
           goods_nomenclature_indents1.oid,
           goods_nomenclature_indents1.operation,
           goods_nomenclature_indents1.operation_date,
           goods_nomenclature_indents1.filename
          FROM goods_nomenclature_indents_oplog goods_nomenclature_indents1
         WHERE ((goods_nomenclature_indents1.oid IN ( SELECT max(goods_nomenclature_indents2.oid) AS max
                  FROM goods_nomenclature_indents_oplog goods_nomenclature_indents2
                 WHERE (goods_nomenclature_indents1.goods_nomenclature_indent_sid = goods_nomenclature_indents2.goods_nomenclature_indent_sid))) AND ((goods_nomenclature_indents1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW goods_nomenclature_origins AS
        SELECT goods_nomenclature_origins1.goods_nomenclature_sid,
           goods_nomenclature_origins1.derived_goods_nomenclature_item_id,
           goods_nomenclature_origins1.derived_productline_suffix,
           goods_nomenclature_origins1.goods_nomenclature_item_id,
           goods_nomenclature_origins1.productline_suffix,
           goods_nomenclature_origins1.oid,
           goods_nomenclature_origins1.operation,
           goods_nomenclature_origins1.operation_date,
           goods_nomenclature_origins1.filename
          FROM goods_nomenclature_origins_oplog goods_nomenclature_origins1
         WHERE ((goods_nomenclature_origins1.oid IN ( SELECT max(goods_nomenclature_origins2.oid) AS max
                  FROM goods_nomenclature_origins_oplog goods_nomenclature_origins2
                 WHERE ((goods_nomenclature_origins1.goods_nomenclature_sid = goods_nomenclature_origins2.goods_nomenclature_sid) AND ((goods_nomenclature_origins1.derived_goods_nomenclature_item_id)::text = (goods_nomenclature_origins2.derived_goods_nomenclature_item_id)::text) AND ((goods_nomenclature_origins1.derived_productline_suffix)::text = (goods_nomenclature_origins2.derived_productline_suffix)::text) AND ((goods_nomenclature_origins1.goods_nomenclature_item_id)::text = (goods_nomenclature_origins2.goods_nomenclature_item_id)::text) AND ((goods_nomenclature_origins1.productline_suffix)::text = (goods_nomenclature_origins2.productline_suffix)::text)))) AND ((goods_nomenclature_origins1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW goods_nomenclature_successors AS
        SELECT goods_nomenclature_successors1.goods_nomenclature_sid,
           goods_nomenclature_successors1.absorbed_goods_nomenclature_item_id,
           goods_nomenclature_successors1.absorbed_productline_suffix,
           goods_nomenclature_successors1.goods_nomenclature_item_id,
           goods_nomenclature_successors1.productline_suffix,
           goods_nomenclature_successors1.oid,
           goods_nomenclature_successors1.operation,
           goods_nomenclature_successors1.operation_date,
           goods_nomenclature_successors1.filename
          FROM goods_nomenclature_successors_oplog goods_nomenclature_successors1
         WHERE ((goods_nomenclature_successors1.oid IN ( SELECT max(goods_nomenclature_successors2.oid) AS max
                  FROM goods_nomenclature_successors_oplog goods_nomenclature_successors2
                 WHERE ((goods_nomenclature_successors1.goods_nomenclature_sid = goods_nomenclature_successors2.goods_nomenclature_sid) AND ((goods_nomenclature_successors1.absorbed_goods_nomenclature_item_id)::text = (goods_nomenclature_successors2.absorbed_goods_nomenclature_item_id)::text) AND ((goods_nomenclature_successors1.absorbed_productline_suffix)::text = (goods_nomenclature_successors2.absorbed_productline_suffix)::text) AND ((goods_nomenclature_successors1.goods_nomenclature_item_id)::text = (goods_nomenclature_successors2.goods_nomenclature_item_id)::text) AND ((goods_nomenclature_successors1.productline_suffix)::text = (goods_nomenclature_successors2.productline_suffix)::text)))) AND ((goods_nomenclature_successors1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW goods_nomenclatures AS
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
               WHEN ((goods_nomenclatures1.goods_nomenclature_item_id)::text ~~ '__00000000'::text) THEN NULL::text
               ELSE "left"((goods_nomenclatures1.goods_nomenclature_item_id)::text, 4)
           END AS heading_short_code,
           "left"((goods_nomenclatures1.goods_nomenclature_item_id)::text, 2) AS chapter_short_code
          FROM goods_nomenclatures_oplog goods_nomenclatures1
         WHERE ((goods_nomenclatures1.oid IN ( SELECT max(goods_nomenclatures2.oid) AS max
                  FROM goods_nomenclatures_oplog goods_nomenclatures2
                 WHERE (goods_nomenclatures1.goods_nomenclature_sid = goods_nomenclatures2.goods_nomenclature_sid))) AND ((goods_nomenclatures1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW language_descriptions AS
        SELECT language_descriptions1.language_code_id,
           language_descriptions1.language_id,
           language_descriptions1.description,
           language_descriptions1.oid,
           language_descriptions1.operation,
           language_descriptions1.operation_date,
           language_descriptions1.filename
          FROM language_descriptions_oplog language_descriptions1
         WHERE ((language_descriptions1.oid IN ( SELECT max(language_descriptions2.oid) AS max
                  FROM language_descriptions_oplog language_descriptions2
                 WHERE (((language_descriptions1.language_id)::text = (language_descriptions2.language_id)::text) AND ((language_descriptions1.language_code_id)::text = (language_descriptions2.language_code_id)::text)))) AND ((language_descriptions1.operation)::text <> 'D'::text));

      CREATE VIEW languages AS
        SELECT languages1.language_id,
           languages1.validity_start_date,
           languages1.validity_end_date,
           languages1.oid,
           languages1.operation,
           languages1.operation_date,
           languages1.filename
          FROM languages_oplog languages1
         WHERE ((languages1.oid IN ( SELECT max(languages2.oid) AS max
                  FROM languages_oplog languages2
                 WHERE ((languages1.language_id)::text = (languages2.language_id)::text))) AND ((languages1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measure_action_descriptions AS
        SELECT measure_action_descriptions1.action_code,
           measure_action_descriptions1.language_id,
           measure_action_descriptions1.description,
           measure_action_descriptions1.oid,
           measure_action_descriptions1.operation,
           measure_action_descriptions1.operation_date,
           measure_action_descriptions1.filename
          FROM measure_action_descriptions_oplog measure_action_descriptions1
         WHERE ((measure_action_descriptions1.oid IN ( SELECT max(measure_action_descriptions2.oid) AS max
                  FROM measure_action_descriptions_oplog measure_action_descriptions2
                 WHERE ((measure_action_descriptions1.action_code)::text = (measure_action_descriptions2.action_code)::text))) AND ((measure_action_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measure_actions AS
        SELECT measure_actions1.action_code,
           measure_actions1.validity_start_date,
           measure_actions1.validity_end_date,
           measure_actions1.oid,
           measure_actions1.operation,
           measure_actions1.operation_date,
           measure_actions1.filename
          FROM measure_actions_oplog measure_actions1
         WHERE ((measure_actions1.oid IN ( SELECT max(measure_actions2.oid) AS max
                  FROM measure_actions_oplog measure_actions2
                 WHERE ((measure_actions1.action_code)::text = (measure_actions2.action_code)::text))) AND ((measure_actions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measure_components AS
        SELECT measure_components1.measure_sid,
           measure_components1.duty_expression_id,
           measure_components1.duty_amount,
           measure_components1.monetary_unit_code,
           measure_components1.measurement_unit_code,
           measure_components1.measurement_unit_qualifier_code,
           measure_components1.oid,
           measure_components1.operation,
           measure_components1.operation_date,
           measure_components1.filename
          FROM measure_components_oplog measure_components1
         WHERE ((measure_components1.oid IN ( SELECT max(measure_components2.oid) AS max
                  FROM measure_components_oplog measure_components2
                 WHERE ((measure_components1.measure_sid = measure_components2.measure_sid) AND ((measure_components1.duty_expression_id)::text = (measure_components2.duty_expression_id)::text)))) AND ((measure_components1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measure_condition_code_descriptions AS
        SELECT measure_condition_code_descriptions1.condition_code,
           measure_condition_code_descriptions1.language_id,
           measure_condition_code_descriptions1.description,
           measure_condition_code_descriptions1.oid,
           measure_condition_code_descriptions1.operation,
           measure_condition_code_descriptions1.operation_date,
           measure_condition_code_descriptions1.filename
          FROM measure_condition_code_descriptions_oplog measure_condition_code_descriptions1
         WHERE ((measure_condition_code_descriptions1.oid IN ( SELECT max(measure_condition_code_descriptions2.oid) AS max
                  FROM measure_condition_code_descriptions_oplog measure_condition_code_descriptions2
                 WHERE ((measure_condition_code_descriptions1.condition_code)::text = (measure_condition_code_descriptions2.condition_code)::text))) AND ((measure_condition_code_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measure_condition_codes AS
        SELECT measure_condition_codes1.condition_code,
           measure_condition_codes1.validity_start_date,
           measure_condition_codes1.validity_end_date,
           measure_condition_codes1.oid,
           measure_condition_codes1.operation,
           measure_condition_codes1.operation_date,
           measure_condition_codes1.filename
          FROM measure_condition_codes_oplog measure_condition_codes1
         WHERE ((measure_condition_codes1.oid IN ( SELECT max(measure_condition_codes2.oid) AS max
                  FROM measure_condition_codes_oplog measure_condition_codes2
                 WHERE ((measure_condition_codes1.condition_code)::text = (measure_condition_codes2.condition_code)::text))) AND ((measure_condition_codes1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measure_condition_components AS
        SELECT measure_condition_components1.measure_condition_sid,
           measure_condition_components1.duty_expression_id,
           measure_condition_components1.duty_amount,
           measure_condition_components1.monetary_unit_code,
           measure_condition_components1.measurement_unit_code,
           measure_condition_components1.measurement_unit_qualifier_code,
           measure_condition_components1.oid,
           measure_condition_components1.operation,
           measure_condition_components1.operation_date,
           measure_condition_components1.filename
          FROM measure_condition_components_oplog measure_condition_components1
         WHERE ((measure_condition_components1.oid IN ( SELECT max(measure_condition_components2.oid) AS max
                  FROM measure_condition_components_oplog measure_condition_components2
                 WHERE ((measure_condition_components1.measure_condition_sid = measure_condition_components2.measure_condition_sid) AND ((measure_condition_components1.duty_expression_id)::text = (measure_condition_components2.duty_expression_id)::text)))) AND ((measure_condition_components1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measure_conditions AS
        SELECT measure_conditions1.measure_condition_sid,
           measure_conditions1.measure_sid,
           measure_conditions1.condition_code,
           measure_conditions1.component_sequence_number,
           measure_conditions1.condition_duty_amount,
           measure_conditions1.condition_monetary_unit_code,
           measure_conditions1.condition_measurement_unit_code,
           measure_conditions1.condition_measurement_unit_qualifier_code,
           measure_conditions1.action_code,
           measure_conditions1.certificate_type_code,
           measure_conditions1.certificate_code,
           measure_conditions1.oid,
           measure_conditions1.operation,
           measure_conditions1.operation_date,
           measure_conditions1.filename
          FROM measure_conditions_oplog measure_conditions1
         WHERE ((measure_conditions1.oid IN ( SELECT max(measure_conditions2.oid) AS max
                  FROM measure_conditions_oplog measure_conditions2
                 WHERE (measure_conditions1.measure_condition_sid = measure_conditions2.measure_condition_sid))) AND ((measure_conditions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measure_excluded_geographical_areas AS
        SELECT measure_excluded_geographical_areas1.measure_sid,
           measure_excluded_geographical_areas1.excluded_geographical_area,
           measure_excluded_geographical_areas1.geographical_area_sid,
           measure_excluded_geographical_areas1.oid,
           measure_excluded_geographical_areas1.operation,
           measure_excluded_geographical_areas1.operation_date,
           measure_excluded_geographical_areas1.filename
          FROM measure_excluded_geographical_areas_oplog measure_excluded_geographical_areas1
         WHERE ((measure_excluded_geographical_areas1.oid IN ( SELECT max(measure_excluded_geographical_areas2.oid) AS max
                  FROM measure_excluded_geographical_areas_oplog measure_excluded_geographical_areas2
                 WHERE ((measure_excluded_geographical_areas1.measure_sid = measure_excluded_geographical_areas2.measure_sid) AND (measure_excluded_geographical_areas1.geographical_area_sid = measure_excluded_geographical_areas2.geographical_area_sid)))) AND ((measure_excluded_geographical_areas1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measure_partial_temporary_stops AS
        SELECT measure_partial_temporary_stops1.measure_sid,
           measure_partial_temporary_stops1.validity_start_date,
           measure_partial_temporary_stops1.validity_end_date,
           measure_partial_temporary_stops1.partial_temporary_stop_regulation_id,
           measure_partial_temporary_stops1.partial_temporary_stop_regulation_officialjournal_number,
           measure_partial_temporary_stops1.partial_temporary_stop_regulation_officialjournal_page,
           measure_partial_temporary_stops1.abrogation_regulation_id,
           measure_partial_temporary_stops1.abrogation_regulation_officialjournal_number,
           measure_partial_temporary_stops1.abrogation_regulation_officialjournal_page,
           measure_partial_temporary_stops1.oid,
           measure_partial_temporary_stops1.operation,
           measure_partial_temporary_stops1.operation_date,
           measure_partial_temporary_stops1.filename
          FROM measure_partial_temporary_stops_oplog measure_partial_temporary_stops1
         WHERE ((measure_partial_temporary_stops1.oid IN ( SELECT max(measure_partial_temporary_stops2.oid) AS max
                  FROM measure_partial_temporary_stops_oplog measure_partial_temporary_stops2
                 WHERE ((measure_partial_temporary_stops1.measure_sid = measure_partial_temporary_stops2.measure_sid) AND ((measure_partial_temporary_stops1.partial_temporary_stop_regulation_id)::text = (measure_partial_temporary_stops2.partial_temporary_stop_regulation_id)::text)))) AND ((measure_partial_temporary_stops1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measure_type_descriptions AS
        SELECT measure_type_descriptions1.measure_type_id,
           measure_type_descriptions1.language_id,
           measure_type_descriptions1.description,
           measure_type_descriptions1."national",
           measure_type_descriptions1.oid,
           measure_type_descriptions1.operation,
           measure_type_descriptions1.operation_date,
           measure_type_descriptions1.filename
          FROM measure_type_descriptions_oplog measure_type_descriptions1
         WHERE ((measure_type_descriptions1.oid IN ( SELECT max(measure_type_descriptions2.oid) AS max
                  FROM measure_type_descriptions_oplog measure_type_descriptions2
                 WHERE ((measure_type_descriptions1.measure_type_id)::text = (measure_type_descriptions2.measure_type_id)::text))) AND ((measure_type_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measure_type_series AS
        SELECT measure_type_series1.measure_type_series_id,
           measure_type_series1.validity_start_date,
           measure_type_series1.validity_end_date,
           measure_type_series1.measure_type_combination,
           measure_type_series1.oid,
           measure_type_series1.operation,
           measure_type_series1.operation_date,
           measure_type_series1.filename
          FROM measure_type_series_oplog measure_type_series1
         WHERE ((measure_type_series1.oid IN ( SELECT max(measure_type_series2.oid) AS max
                  FROM measure_type_series_oplog measure_type_series2
                 WHERE ((measure_type_series1.measure_type_series_id)::text = (measure_type_series2.measure_type_series_id)::text))) AND ((measure_type_series1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measure_type_series_descriptions AS
        SELECT measure_type_series_descriptions1.measure_type_series_id,
           measure_type_series_descriptions1.language_id,
           measure_type_series_descriptions1.description,
           measure_type_series_descriptions1.oid,
           measure_type_series_descriptions1.operation,
           measure_type_series_descriptions1.operation_date,
           measure_type_series_descriptions1.filename
          FROM measure_type_series_descriptions_oplog measure_type_series_descriptions1
         WHERE ((measure_type_series_descriptions1.oid IN ( SELECT max(measure_type_series_descriptions2.oid) AS max
                  FROM measure_type_series_descriptions_oplog measure_type_series_descriptions2
                 WHERE ((measure_type_series_descriptions1.measure_type_series_id)::text = (measure_type_series_descriptions2.measure_type_series_id)::text))) AND ((measure_type_series_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measure_types AS
        SELECT measure_types1.measure_type_id,
           measure_types1.validity_start_date,
           measure_types1.validity_end_date,
           measure_types1.trade_movement_code,
           measure_types1.priority_code,
           measure_types1.measure_component_applicable_code,
           measure_types1.origin_dest_code,
           measure_types1.order_number_capture_code,
           measure_types1.measure_explosion_level,
           measure_types1.measure_type_series_id,
           measure_types1."national",
           measure_types1.measure_type_acronym,
           measure_types1.oid,
           measure_types1.operation,
           measure_types1.operation_date,
           measure_types1.filename
          FROM measure_types_oplog measure_types1
         WHERE ((measure_types1.oid IN ( SELECT max(measure_types2.oid) AS max
                  FROM measure_types_oplog measure_types2
                 WHERE ((measure_types1.measure_type_id)::text = (measure_types2.measure_type_id)::text))) AND ((measure_types1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measurement_unit_descriptions AS
        SELECT measurement_unit_descriptions1.measurement_unit_code,
           measurement_unit_descriptions1.language_id,
           measurement_unit_descriptions1.description,
           measurement_unit_descriptions1.oid,
           measurement_unit_descriptions1.operation,
           measurement_unit_descriptions1.operation_date,
           measurement_unit_descriptions1.filename
          FROM measurement_unit_descriptions_oplog measurement_unit_descriptions1
         WHERE ((measurement_unit_descriptions1.oid IN ( SELECT max(measurement_unit_descriptions2.oid) AS max
                  FROM measurement_unit_descriptions_oplog measurement_unit_descriptions2
                 WHERE ((measurement_unit_descriptions1.measurement_unit_code)::text = (measurement_unit_descriptions2.measurement_unit_code)::text))) AND ((measurement_unit_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measurement_unit_qualifier_descriptions AS
        SELECT measurement_unit_qualifier_descriptions1.measurement_unit_qualifier_code,
           measurement_unit_qualifier_descriptions1.language_id,
           measurement_unit_qualifier_descriptions1.description,
           measurement_unit_qualifier_descriptions1.oid,
           measurement_unit_qualifier_descriptions1.operation,
           measurement_unit_qualifier_descriptions1.operation_date,
           measurement_unit_qualifier_descriptions1.filename
          FROM measurement_unit_qualifier_descriptions_oplog measurement_unit_qualifier_descriptions1
         WHERE ((measurement_unit_qualifier_descriptions1.oid IN ( SELECT max(measurement_unit_qualifier_descriptions2.oid) AS max
                  FROM measurement_unit_qualifier_descriptions_oplog measurement_unit_qualifier_descriptions2
                 WHERE ((measurement_unit_qualifier_descriptions1.measurement_unit_qualifier_code)::text = (measurement_unit_qualifier_descriptions2.measurement_unit_qualifier_code)::text))) AND ((measurement_unit_qualifier_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measurement_unit_qualifiers AS
        SELECT measurement_unit_qualifiers1.measurement_unit_qualifier_code,
           measurement_unit_qualifiers1.validity_start_date,
           measurement_unit_qualifiers1.validity_end_date,
           measurement_unit_qualifiers1.oid,
           measurement_unit_qualifiers1.operation,
           measurement_unit_qualifiers1.operation_date,
           measurement_unit_qualifiers1.filename
          FROM measurement_unit_qualifiers_oplog measurement_unit_qualifiers1
         WHERE ((measurement_unit_qualifiers1.oid IN ( SELECT max(measurement_unit_qualifiers2.oid) AS max
                  FROM measurement_unit_qualifiers_oplog measurement_unit_qualifiers2
                 WHERE ((measurement_unit_qualifiers1.measurement_unit_qualifier_code)::text = (measurement_unit_qualifiers2.measurement_unit_qualifier_code)::text))) AND ((measurement_unit_qualifiers1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measurement_units AS
        SELECT measurement_units1.measurement_unit_code,
           measurement_units1.validity_start_date,
           measurement_units1.validity_end_date,
           measurement_units1.oid,
           measurement_units1.operation,
           measurement_units1.operation_date,
           measurement_units1.filename
          FROM measurement_units_oplog measurement_units1
         WHERE ((measurement_units1.oid IN ( SELECT max(measurement_units2.oid) AS max
                  FROM measurement_units_oplog measurement_units2
                 WHERE ((measurement_units1.measurement_unit_code)::text = (measurement_units2.measurement_unit_code)::text))) AND ((measurement_units1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measurements AS
        SELECT measurements1.measurement_unit_code,
           measurements1.measurement_unit_qualifier_code,
           measurements1.validity_start_date,
           measurements1.validity_end_date,
           measurements1.oid,
           measurements1.operation,
           measurements1.operation_date,
           measurements1.filename
          FROM measurements_oplog measurements1
         WHERE ((measurements1.oid IN ( SELECT max(measurements2.oid) AS max
                  FROM measurements_oplog measurements2
                 WHERE (((measurements1.measurement_unit_code)::text = (measurements2.measurement_unit_code)::text) AND ((measurements1.measurement_unit_qualifier_code)::text = (measurements2.measurement_unit_qualifier_code)::text)))) AND ((measurements1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW measures AS
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
         WHERE ((measures1.oid IN ( SELECT max(measures2.oid) AS max
                  FROM measures_oplog measures2
                 WHERE (measures1.measure_sid = measures2.measure_sid))) AND ((measures1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW meursing_additional_codes AS
        SELECT meursing_additional_codes1.meursing_additional_code_sid,
           meursing_additional_codes1.additional_code,
           meursing_additional_codes1.validity_start_date,
           meursing_additional_codes1.validity_end_date,
           meursing_additional_codes1.oid,
           meursing_additional_codes1.operation,
           meursing_additional_codes1.operation_date,
           meursing_additional_codes1.filename
          FROM meursing_additional_codes_oplog meursing_additional_codes1
         WHERE ((meursing_additional_codes1.oid IN ( SELECT max(meursing_additional_codes2.oid) AS max
                  FROM meursing_additional_codes_oplog meursing_additional_codes2
                 WHERE (meursing_additional_codes1.meursing_additional_code_sid = meursing_additional_codes2.meursing_additional_code_sid))) AND ((meursing_additional_codes1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW meursing_heading_texts AS
        SELECT meursing_heading_texts1.meursing_table_plan_id,
           meursing_heading_texts1.meursing_heading_number,
           meursing_heading_texts1.row_column_code,
           meursing_heading_texts1.language_id,
           meursing_heading_texts1.description,
           meursing_heading_texts1.oid,
           meursing_heading_texts1.operation,
           meursing_heading_texts1.operation_date,
           meursing_heading_texts1.filename
          FROM meursing_heading_texts_oplog meursing_heading_texts1
         WHERE ((meursing_heading_texts1.oid IN ( SELECT max(meursing_heading_texts2.oid) AS max
                  FROM meursing_heading_texts_oplog meursing_heading_texts2
                 WHERE (((meursing_heading_texts1.meursing_table_plan_id)::text = (meursing_heading_texts2.meursing_table_plan_id)::text) AND (meursing_heading_texts1.meursing_heading_number = meursing_heading_texts2.meursing_heading_number) AND (meursing_heading_texts1.row_column_code = meursing_heading_texts2.row_column_code)))) AND ((meursing_heading_texts1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW meursing_headings AS
        SELECT meursing_headings1.meursing_table_plan_id,
           meursing_headings1.meursing_heading_number,
           meursing_headings1.row_column_code,
           meursing_headings1.validity_start_date,
           meursing_headings1.validity_end_date,
           meursing_headings1.oid,
           meursing_headings1.operation,
           meursing_headings1.operation_date,
           meursing_headings1.filename
          FROM meursing_headings_oplog meursing_headings1
         WHERE ((meursing_headings1.oid IN ( SELECT max(meursing_headings2.oid) AS max
                  FROM meursing_headings_oplog meursing_headings2
                 WHERE (((meursing_headings1.meursing_table_plan_id)::text = (meursing_headings2.meursing_table_plan_id)::text) AND (meursing_headings1.meursing_heading_number = meursing_headings2.meursing_heading_number) AND (meursing_headings1.row_column_code = meursing_headings2.row_column_code)))) AND ((meursing_headings1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW meursing_subheadings AS
        SELECT meursing_subheadings1.meursing_table_plan_id,
           meursing_subheadings1.meursing_heading_number,
           meursing_subheadings1.row_column_code,
           meursing_subheadings1.subheading_sequence_number,
           meursing_subheadings1.validity_start_date,
           meursing_subheadings1.validity_end_date,
           meursing_subheadings1.description,
           meursing_subheadings1.oid,
           meursing_subheadings1.operation,
           meursing_subheadings1.operation_date,
           meursing_subheadings1.filename
          FROM meursing_subheadings_oplog meursing_subheadings1
         WHERE ((meursing_subheadings1.oid IN ( SELECT max(meursing_subheadings2.oid) AS max
                  FROM meursing_subheadings_oplog meursing_subheadings2
                 WHERE (((meursing_subheadings1.meursing_table_plan_id)::text = (meursing_subheadings2.meursing_table_plan_id)::text) AND (meursing_subheadings1.meursing_heading_number = meursing_subheadings2.meursing_heading_number) AND (meursing_subheadings1.row_column_code = meursing_subheadings2.row_column_code) AND (meursing_subheadings1.subheading_sequence_number = meursing_subheadings2.subheading_sequence_number)))) AND ((meursing_subheadings1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW meursing_table_cell_components AS
        SELECT meursing_table_cell_components1.meursing_additional_code_sid,
           meursing_table_cell_components1.meursing_table_plan_id,
           meursing_table_cell_components1.heading_number,
           meursing_table_cell_components1.row_column_code,
           meursing_table_cell_components1.subheading_sequence_number,
           meursing_table_cell_components1.validity_start_date,
           meursing_table_cell_components1.validity_end_date,
           meursing_table_cell_components1.additional_code,
           meursing_table_cell_components1.oid,
           meursing_table_cell_components1.operation,
           meursing_table_cell_components1.operation_date,
           meursing_table_cell_components1.filename
          FROM meursing_table_cell_components_oplog meursing_table_cell_components1
         WHERE ((meursing_table_cell_components1.oid IN ( SELECT max(meursing_table_cell_components2.oid) AS max
                  FROM meursing_table_cell_components_oplog meursing_table_cell_components2
                 WHERE (((meursing_table_cell_components1.meursing_table_plan_id)::text = (meursing_table_cell_components2.meursing_table_plan_id)::text) AND (meursing_table_cell_components1.heading_number = meursing_table_cell_components2.heading_number) AND (meursing_table_cell_components1.row_column_code = meursing_table_cell_components2.row_column_code) AND (meursing_table_cell_components1.meursing_additional_code_sid = meursing_table_cell_components2.meursing_additional_code_sid)))) AND ((meursing_table_cell_components1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW meursing_table_plans AS
        SELECT meursing_table_plans1.meursing_table_plan_id,
           meursing_table_plans1.validity_start_date,
           meursing_table_plans1.validity_end_date,
           meursing_table_plans1.oid,
           meursing_table_plans1.operation,
           meursing_table_plans1.operation_date,
           meursing_table_plans1.filename
          FROM meursing_table_plans_oplog meursing_table_plans1
         WHERE ((meursing_table_plans1.oid IN ( SELECT max(meursing_table_plans2.oid) AS max
                  FROM meursing_table_plans_oplog meursing_table_plans2
                 WHERE ((meursing_table_plans1.meursing_table_plan_id)::text = (meursing_table_plans2.meursing_table_plan_id)::text))) AND ((meursing_table_plans1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW modification_regulations AS
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
         WHERE ((modification_regulations1.oid IN ( SELECT max(modification_regulations2.oid) AS max
                  FROM modification_regulations_oplog modification_regulations2
                 WHERE (((modification_regulations1.modification_regulation_id)::text = (modification_regulations2.modification_regulation_id)::text) AND (modification_regulations1.modification_regulation_role = modification_regulations2.modification_regulation_role)))) AND ((modification_regulations1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW monetary_exchange_periods AS
        SELECT monetary_exchange_periods1.monetary_exchange_period_sid,
           monetary_exchange_periods1.parent_monetary_unit_code,
           monetary_exchange_periods1.validity_start_date,
           monetary_exchange_periods1.validity_end_date,
           monetary_exchange_periods1.oid,
           monetary_exchange_periods1.operation,
           monetary_exchange_periods1.operation_date,
           monetary_exchange_periods1.filename
          FROM monetary_exchange_periods_oplog monetary_exchange_periods1
         WHERE ((monetary_exchange_periods1.oid IN ( SELECT max(monetary_exchange_periods2.oid) AS max
                  FROM monetary_exchange_periods_oplog monetary_exchange_periods2
                 WHERE ((monetary_exchange_periods1.monetary_exchange_period_sid = monetary_exchange_periods2.monetary_exchange_period_sid) AND ((monetary_exchange_periods1.parent_monetary_unit_code)::text = (monetary_exchange_periods2.parent_monetary_unit_code)::text)))) AND ((monetary_exchange_periods1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW monetary_exchange_rates AS
        SELECT monetary_exchange_rates1.monetary_exchange_period_sid,
           monetary_exchange_rates1.child_monetary_unit_code,
           monetary_exchange_rates1.exchange_rate,
           monetary_exchange_rates1.oid,
           monetary_exchange_rates1.operation,
           monetary_exchange_rates1.operation_date,
           monetary_exchange_rates1.filename
          FROM monetary_exchange_rates_oplog monetary_exchange_rates1
         WHERE ((monetary_exchange_rates1.oid IN ( SELECT max(monetary_exchange_rates2.oid) AS max
                  FROM monetary_exchange_rates_oplog monetary_exchange_rates2
                 WHERE ((monetary_exchange_rates1.monetary_exchange_period_sid = monetary_exchange_rates2.monetary_exchange_period_sid) AND ((monetary_exchange_rates1.child_monetary_unit_code)::text = (monetary_exchange_rates2.child_monetary_unit_code)::text)))) AND ((monetary_exchange_rates1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW monetary_unit_descriptions AS
        SELECT monetary_unit_descriptions1.monetary_unit_code,
           monetary_unit_descriptions1.language_id,
           monetary_unit_descriptions1.description,
           monetary_unit_descriptions1.oid,
           monetary_unit_descriptions1.operation,
           monetary_unit_descriptions1.operation_date,
           monetary_unit_descriptions1.filename
          FROM monetary_unit_descriptions_oplog monetary_unit_descriptions1
         WHERE ((monetary_unit_descriptions1.oid IN ( SELECT max(monetary_unit_descriptions2.oid) AS max
                  FROM monetary_unit_descriptions_oplog monetary_unit_descriptions2
                 WHERE ((monetary_unit_descriptions1.monetary_unit_code)::text = (monetary_unit_descriptions2.monetary_unit_code)::text))) AND ((monetary_unit_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW monetary_units AS
        SELECT monetary_units1.monetary_unit_code,
           monetary_units1.validity_start_date,
           monetary_units1.validity_end_date,
           monetary_units1.oid,
           monetary_units1.operation,
           monetary_units1.operation_date,
           monetary_units1.filename
          FROM monetary_units_oplog monetary_units1
         WHERE ((monetary_units1.oid IN ( SELECT max(monetary_units2.oid) AS max
                  FROM monetary_units_oplog monetary_units2
                 WHERE ((monetary_units1.monetary_unit_code)::text = (monetary_units2.monetary_unit_code)::text))) AND ((monetary_units1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW nomenclature_group_memberships AS
        SELECT nomenclature_group_memberships1.goods_nomenclature_sid,
           nomenclature_group_memberships1.goods_nomenclature_group_type,
           nomenclature_group_memberships1.goods_nomenclature_group_id,
           nomenclature_group_memberships1.validity_start_date,
           nomenclature_group_memberships1.validity_end_date,
           nomenclature_group_memberships1.goods_nomenclature_item_id,
           nomenclature_group_memberships1.productline_suffix,
           nomenclature_group_memberships1.oid,
           nomenclature_group_memberships1.operation,
           nomenclature_group_memberships1.operation_date,
           nomenclature_group_memberships1.filename
          FROM nomenclature_group_memberships_oplog nomenclature_group_memberships1
         WHERE ((nomenclature_group_memberships1.oid IN ( SELECT max(nomenclature_group_memberships2.oid) AS max
                  FROM nomenclature_group_memberships_oplog nomenclature_group_memberships2
                 WHERE ((nomenclature_group_memberships1.goods_nomenclature_sid = nomenclature_group_memberships2.goods_nomenclature_sid) AND ((nomenclature_group_memberships1.goods_nomenclature_group_id)::text = (nomenclature_group_memberships2.goods_nomenclature_group_id)::text) AND ((nomenclature_group_memberships1.goods_nomenclature_group_type)::text = (nomenclature_group_memberships2.goods_nomenclature_group_type)::text) AND ((nomenclature_group_memberships1.goods_nomenclature_item_id)::text = (nomenclature_group_memberships2.goods_nomenclature_item_id)::text) AND (nomenclature_group_memberships1.validity_start_date = nomenclature_group_memberships2.validity_start_date)))) AND ((nomenclature_group_memberships1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW prorogation_regulation_actions AS
        SELECT prorogation_regulation_actions1.prorogation_regulation_role,
           prorogation_regulation_actions1.prorogation_regulation_id,
           prorogation_regulation_actions1.prorogated_regulation_role,
           prorogation_regulation_actions1.prorogated_regulation_id,
           prorogation_regulation_actions1.prorogated_date,
           prorogation_regulation_actions1.oid,
           prorogation_regulation_actions1.operation,
           prorogation_regulation_actions1.operation_date,
           prorogation_regulation_actions1.filename
          FROM prorogation_regulation_actions_oplog prorogation_regulation_actions1
         WHERE ((prorogation_regulation_actions1.oid IN ( SELECT max(prorogation_regulation_actions2.oid) AS max
                  FROM prorogation_regulation_actions_oplog prorogation_regulation_actions2
                 WHERE (((prorogation_regulation_actions1.prorogation_regulation_id)::text = (prorogation_regulation_actions2.prorogation_regulation_id)::text) AND (prorogation_regulation_actions1.prorogation_regulation_role = prorogation_regulation_actions2.prorogation_regulation_role) AND ((prorogation_regulation_actions1.prorogated_regulation_id)::text = (prorogation_regulation_actions2.prorogated_regulation_id)::text) AND (prorogation_regulation_actions1.prorogated_regulation_role = prorogation_regulation_actions2.prorogated_regulation_role)))) AND ((prorogation_regulation_actions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW prorogation_regulations AS
        SELECT prorogation_regulations1.prorogation_regulation_role,
           prorogation_regulations1.prorogation_regulation_id,
           prorogation_regulations1.published_date,
           prorogation_regulations1.officialjournal_number,
           prorogation_regulations1.officialjournal_page,
           prorogation_regulations1.replacement_indicator,
           prorogation_regulations1.information_text,
           prorogation_regulations1.approved_flag,
           prorogation_regulations1.oid,
           prorogation_regulations1.operation,
           prorogation_regulations1.operation_date,
           prorogation_regulations1.filename
          FROM prorogation_regulations_oplog prorogation_regulations1
         WHERE ((prorogation_regulations1.oid IN ( SELECT max(prorogation_regulations2.oid) AS max
                  FROM prorogation_regulations_oplog prorogation_regulations2
                 WHERE (((prorogation_regulations1.prorogation_regulation_id)::text = (prorogation_regulations2.prorogation_regulation_id)::text) AND (prorogation_regulations1.prorogation_regulation_role = prorogation_regulations2.prorogation_regulation_role)))) AND ((prorogation_regulations1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW publication_sigles AS
        SELECT publication_sigles1.oid,
           publication_sigles1.code_type_id,
           publication_sigles1.code,
           publication_sigles1.publication_code,
           publication_sigles1.publication_sigle,
           publication_sigles1.validity_end_date,
           publication_sigles1.validity_start_date,
           publication_sigles1.operation,
           publication_sigles1.operation_date,
           publication_sigles1.filename
          FROM publication_sigles_oplog publication_sigles1
         WHERE ((publication_sigles1.oid IN ( SELECT max(publication_sigles2.oid) AS max
                  FROM publication_sigles_oplog publication_sigles2
                 WHERE (((publication_sigles1.code)::text = (publication_sigles2.code)::text) AND ((publication_sigles1.code_type_id)::text = (publication_sigles2.code_type_id)::text)))) AND ((publication_sigles1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW quota_associations AS
        SELECT quota_associations1.main_quota_definition_sid,
           quota_associations1.sub_quota_definition_sid,
           quota_associations1.relation_type,
           quota_associations1.coefficient,
           quota_associations1.oid,
           quota_associations1.operation,
           quota_associations1.operation_date,
           quota_associations1.filename
          FROM quota_associations_oplog quota_associations1
         WHERE ((quota_associations1.oid IN ( SELECT max(quota_associations2.oid) AS max
                  FROM quota_associations_oplog quota_associations2
                 WHERE ((quota_associations1.main_quota_definition_sid = quota_associations2.main_quota_definition_sid) AND (quota_associations1.sub_quota_definition_sid = quota_associations2.sub_quota_definition_sid)))) AND ((quota_associations1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW quota_balance_events AS
        SELECT quota_balance_events1.quota_definition_sid,
           quota_balance_events1.occurrence_timestamp,
           quota_balance_events1.last_import_date_in_allocation,
           quota_balance_events1.old_balance,
           quota_balance_events1.new_balance,
           quota_balance_events1.imported_amount,
           quota_balance_events1.oid,
           quota_balance_events1.operation,
           quota_balance_events1.operation_date,
           quota_balance_events1.filename
          FROM quota_balance_events_oplog quota_balance_events1
         WHERE ((quota_balance_events1.oid IN ( SELECT max(quota_balance_events2.oid) AS max
                  FROM quota_balance_events_oplog quota_balance_events2
                 WHERE ((quota_balance_events1.quota_definition_sid = quota_balance_events2.quota_definition_sid) AND (quota_balance_events1.occurrence_timestamp = quota_balance_events2.occurrence_timestamp)))) AND ((quota_balance_events1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW quota_blocking_periods AS
        SELECT quota_blocking_periods1.quota_blocking_period_sid,
           quota_blocking_periods1.quota_definition_sid,
           quota_blocking_periods1.blocking_start_date,
           quota_blocking_periods1.blocking_end_date,
           quota_blocking_periods1.blocking_period_type,
           quota_blocking_periods1.description,
           quota_blocking_periods1.oid,
           quota_blocking_periods1.operation,
           quota_blocking_periods1.operation_date,
           quota_blocking_periods1.filename
          FROM quota_blocking_periods_oplog quota_blocking_periods1
         WHERE ((quota_blocking_periods1.oid IN ( SELECT max(quota_blocking_periods2.oid) AS max
                  FROM quota_blocking_periods_oplog quota_blocking_periods2
                 WHERE (quota_blocking_periods1.quota_blocking_period_sid = quota_blocking_periods2.quota_blocking_period_sid))) AND ((quota_blocking_periods1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW quota_closed_and_transferred_events AS
        SELECT quota_closed_and_transferred_events1.oid,
           quota_closed_and_transferred_events1.quota_definition_sid,
           quota_closed_and_transferred_events1.target_quota_definition_sid,
           quota_closed_and_transferred_events1.occurrence_timestamp,
           quota_closed_and_transferred_events1.operation,
           quota_closed_and_transferred_events1.operation_date,
           quota_closed_and_transferred_events1.transferred_amount,
           quota_closed_and_transferred_events1.closing_date,
           quota_closed_and_transferred_events1.filename
          FROM quota_closed_and_transferred_events_oplog quota_closed_and_transferred_events1
         WHERE ((quota_closed_and_transferred_events1.oid IN ( SELECT max(quota_closed_and_transferred_events2.oid) AS max
                  FROM quota_closed_and_transferred_events_oplog quota_closed_and_transferred_events2
                 WHERE ((quota_closed_and_transferred_events1.quota_definition_sid = quota_closed_and_transferred_events2.quota_definition_sid) AND (quota_closed_and_transferred_events1.occurrence_timestamp = quota_closed_and_transferred_events2.occurrence_timestamp)))) AND ((quota_closed_and_transferred_events1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW quota_critical_events AS
        SELECT quota_critical_events1.quota_definition_sid,
           quota_critical_events1.occurrence_timestamp,
           quota_critical_events1.critical_state,
           quota_critical_events1.critical_state_change_date,
           quota_critical_events1.oid,
           quota_critical_events1.operation,
           quota_critical_events1.operation_date,
           quota_critical_events1.filename
          FROM quota_critical_events_oplog quota_critical_events1
         WHERE ((quota_critical_events1.oid IN ( SELECT max(quota_critical_events2.oid) AS max
                  FROM quota_critical_events_oplog quota_critical_events2
                 WHERE ((quota_critical_events1.quota_definition_sid = quota_critical_events2.quota_definition_sid) AND (quota_critical_events1.occurrence_timestamp = quota_critical_events2.occurrence_timestamp)))) AND ((quota_critical_events1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW quota_definitions AS
        SELECT quota_definitions1.quota_definition_sid,
           quota_definitions1.quota_order_number_id,
           quota_definitions1.validity_start_date,
           quota_definitions1.validity_end_date,
           quota_definitions1.quota_order_number_sid,
           quota_definitions1.volume,
           quota_definitions1.initial_volume,
           quota_definitions1.measurement_unit_code,
           quota_definitions1.maximum_precision,
           quota_definitions1.critical_state,
           quota_definitions1.critical_threshold,
           quota_definitions1.monetary_unit_code,
           quota_definitions1.measurement_unit_qualifier_code,
           quota_definitions1.description,
           quota_definitions1.oid,
           quota_definitions1.operation,
           quota_definitions1.operation_date,
           quota_definitions1.filename
          FROM quota_definitions_oplog quota_definitions1
         WHERE ((quota_definitions1.oid IN ( SELECT max(quota_definitions2.oid) AS max
                  FROM quota_definitions_oplog quota_definitions2
                 WHERE (quota_definitions1.quota_definition_sid = quota_definitions2.quota_definition_sid))) AND ((quota_definitions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW quota_exhaustion_events AS
        SELECT quota_exhaustion_events1.quota_definition_sid,
           quota_exhaustion_events1.occurrence_timestamp,
           quota_exhaustion_events1.exhaustion_date,
           quota_exhaustion_events1.oid,
           quota_exhaustion_events1.operation,
           quota_exhaustion_events1.operation_date,
           quota_exhaustion_events1.filename
          FROM quota_exhaustion_events_oplog quota_exhaustion_events1
         WHERE ((quota_exhaustion_events1.oid IN ( SELECT max(quota_exhaustion_events2.oid) AS max
                  FROM quota_exhaustion_events_oplog quota_exhaustion_events2
                 WHERE ((quota_exhaustion_events1.quota_definition_sid = quota_exhaustion_events2.quota_definition_sid) AND (quota_exhaustion_events1.occurrence_timestamp = quota_exhaustion_events2.occurrence_timestamp)))) AND ((quota_exhaustion_events1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW quota_order_number_origin_exclusions AS
        SELECT quota_order_number_origin_exclusions1.quota_order_number_origin_sid,
           quota_order_number_origin_exclusions1.excluded_geographical_area_sid,
           quota_order_number_origin_exclusions1.oid,
           quota_order_number_origin_exclusions1.operation,
           quota_order_number_origin_exclusions1.operation_date,
           quota_order_number_origin_exclusions1.filename
          FROM quota_order_number_origin_exclusions_oplog quota_order_number_origin_exclusions1
         WHERE ((quota_order_number_origin_exclusions1.oid IN ( SELECT max(quota_order_number_origin_exclusions2.oid) AS max
                  FROM quota_order_number_origin_exclusions_oplog quota_order_number_origin_exclusions2
                 WHERE ((quota_order_number_origin_exclusions1.quota_order_number_origin_sid = quota_order_number_origin_exclusions2.quota_order_number_origin_sid) AND (quota_order_number_origin_exclusions1.excluded_geographical_area_sid = quota_order_number_origin_exclusions2.excluded_geographical_area_sid)))) AND ((quota_order_number_origin_exclusions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW quota_order_number_origins AS
        SELECT quota_order_number_origins1.quota_order_number_origin_sid,
           quota_order_number_origins1.quota_order_number_sid,
           quota_order_number_origins1.geographical_area_id,
           quota_order_number_origins1.validity_start_date,
           quota_order_number_origins1.validity_end_date,
           quota_order_number_origins1.geographical_area_sid,
           quota_order_number_origins1.oid,
           quota_order_number_origins1.operation,
           quota_order_number_origins1.operation_date,
           quota_order_number_origins1.filename
          FROM quota_order_number_origins_oplog quota_order_number_origins1
         WHERE ((quota_order_number_origins1.oid IN ( SELECT max(quota_order_number_origins2.oid) AS max
                  FROM quota_order_number_origins_oplog quota_order_number_origins2
                 WHERE (quota_order_number_origins1.quota_order_number_origin_sid = quota_order_number_origins2.quota_order_number_origin_sid))) AND ((quota_order_number_origins1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW quota_order_numbers AS
        SELECT quota_order_numbers1.quota_order_number_sid,
           quota_order_numbers1.quota_order_number_id,
           quota_order_numbers1.validity_start_date,
           quota_order_numbers1.validity_end_date,
           quota_order_numbers1.oid,
           quota_order_numbers1.operation,
           quota_order_numbers1.operation_date,
           quota_order_numbers1.filename
          FROM quota_order_numbers_oplog quota_order_numbers1
         WHERE ((quota_order_numbers1.oid IN ( SELECT max(quota_order_numbers2.oid) AS max
                  FROM quota_order_numbers_oplog quota_order_numbers2
                 WHERE (quota_order_numbers1.quota_order_number_sid = quota_order_numbers2.quota_order_number_sid))) AND ((quota_order_numbers1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW quota_reopening_events AS
        SELECT quota_reopening_events1.quota_definition_sid,
           quota_reopening_events1.occurrence_timestamp,
           quota_reopening_events1.reopening_date,
           quota_reopening_events1.oid,
           quota_reopening_events1.operation,
           quota_reopening_events1.operation_date,
           quota_reopening_events1.filename
          FROM quota_reopening_events_oplog quota_reopening_events1
         WHERE ((quota_reopening_events1.oid IN ( SELECT max(quota_reopening_events2.oid) AS max
                  FROM quota_reopening_events_oplog quota_reopening_events2
                 WHERE ((quota_reopening_events1.quota_definition_sid = quota_reopening_events2.quota_definition_sid) AND (quota_reopening_events1.occurrence_timestamp = quota_reopening_events2.occurrence_timestamp)))) AND ((quota_reopening_events1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW quota_suspension_periods AS
        SELECT quota_suspension_periods1.quota_suspension_period_sid,
           quota_suspension_periods1.quota_definition_sid,
           quota_suspension_periods1.suspension_start_date,
           quota_suspension_periods1.suspension_end_date,
           quota_suspension_periods1.description,
           quota_suspension_periods1.oid,
           quota_suspension_periods1.operation,
           quota_suspension_periods1.operation_date,
           quota_suspension_periods1.filename
          FROM quota_suspension_periods_oplog quota_suspension_periods1
         WHERE ((quota_suspension_periods1.oid IN ( SELECT max(quota_suspension_periods2.oid) AS max
                  FROM quota_suspension_periods_oplog quota_suspension_periods2
                 WHERE (quota_suspension_periods1.quota_suspension_period_sid = quota_suspension_periods2.quota_suspension_period_sid))) AND ((quota_suspension_periods1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW quota_unblocking_events AS
        SELECT quota_unblocking_events1.quota_definition_sid,
           quota_unblocking_events1.occurrence_timestamp,
           quota_unblocking_events1.unblocking_date,
           quota_unblocking_events1.oid,
           quota_unblocking_events1.operation,
           quota_unblocking_events1.operation_date,
           quota_unblocking_events1.filename
          FROM quota_unblocking_events_oplog quota_unblocking_events1
         WHERE ((quota_unblocking_events1.oid IN ( SELECT max(quota_unblocking_events2.oid) AS max
                  FROM quota_unblocking_events_oplog quota_unblocking_events2
                 WHERE (quota_unblocking_events1.quota_definition_sid = quota_unblocking_events2.quota_definition_sid))) AND ((quota_unblocking_events1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW quota_unsuspension_events AS
        SELECT quota_unsuspension_events1.quota_definition_sid,
           quota_unsuspension_events1.occurrence_timestamp,
           quota_unsuspension_events1.unsuspension_date,
           quota_unsuspension_events1.oid,
           quota_unsuspension_events1.operation,
           quota_unsuspension_events1.operation_date,
           quota_unsuspension_events1.filename
          FROM quota_unsuspension_events_oplog quota_unsuspension_events1
         WHERE ((quota_unsuspension_events1.oid IN ( SELECT max(quota_unsuspension_events2.oid) AS max
                  FROM quota_unsuspension_events_oplog quota_unsuspension_events2
                 WHERE ((quota_unsuspension_events1.quota_definition_sid = quota_unsuspension_events2.quota_definition_sid) AND (quota_unsuspension_events1.occurrence_timestamp = quota_unsuspension_events2.occurrence_timestamp)))) AND ((quota_unsuspension_events1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW regulation_group_descriptions AS
        SELECT regulation_group_descriptions1.regulation_group_id,
           regulation_group_descriptions1.language_id,
           regulation_group_descriptions1.description,
           regulation_group_descriptions1."national",
           regulation_group_descriptions1.oid,
           regulation_group_descriptions1.operation,
           regulation_group_descriptions1.operation_date,
           regulation_group_descriptions1.filename
          FROM regulation_group_descriptions_oplog regulation_group_descriptions1
         WHERE ((regulation_group_descriptions1.oid IN ( SELECT max(regulation_group_descriptions2.oid) AS max
                  FROM regulation_group_descriptions_oplog regulation_group_descriptions2
                 WHERE ((regulation_group_descriptions1.regulation_group_id)::text = (regulation_group_descriptions2.regulation_group_id)::text))) AND ((regulation_group_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW regulation_groups AS
        SELECT regulation_groups1.regulation_group_id,
           regulation_groups1.validity_start_date,
           regulation_groups1.validity_end_date,
           regulation_groups1."national",
           regulation_groups1.oid,
           regulation_groups1.operation,
           regulation_groups1.operation_date,
           regulation_groups1.filename
          FROM regulation_groups_oplog regulation_groups1
         WHERE ((regulation_groups1.oid IN ( SELECT max(regulation_groups2.oid) AS max
                  FROM regulation_groups_oplog regulation_groups2
                 WHERE ((regulation_groups1.regulation_group_id)::text = (regulation_groups2.regulation_group_id)::text))) AND ((regulation_groups1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW regulation_replacements AS
        SELECT regulation_replacements1.geographical_area_id,
           regulation_replacements1.chapter_heading,
           regulation_replacements1.replacing_regulation_role,
           regulation_replacements1.replacing_regulation_id,
           regulation_replacements1.replaced_regulation_role,
           regulation_replacements1.replaced_regulation_id,
           regulation_replacements1.measure_type_id,
           regulation_replacements1.oid,
           regulation_replacements1.operation,
           regulation_replacements1.operation_date,
           regulation_replacements1.filename
          FROM regulation_replacements_oplog regulation_replacements1
         WHERE ((regulation_replacements1.oid IN ( SELECT max(regulation_replacements2.oid) AS max
                  FROM regulation_replacements_oplog regulation_replacements2
                 WHERE (((regulation_replacements1.replacing_regulation_id)::text = (regulation_replacements2.replacing_regulation_id)::text) AND (regulation_replacements1.replacing_regulation_role = regulation_replacements2.replacing_regulation_role) AND ((regulation_replacements1.replaced_regulation_id)::text = (regulation_replacements2.replaced_regulation_id)::text) AND (regulation_replacements1.replaced_regulation_role = regulation_replacements2.replaced_regulation_role)))) AND ((regulation_replacements1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW regulation_role_type_descriptions AS
        SELECT regulation_role_type_descriptions1.regulation_role_type_id,
           regulation_role_type_descriptions1.language_id,
           regulation_role_type_descriptions1.description,
           regulation_role_type_descriptions1."national",
           regulation_role_type_descriptions1.oid,
           regulation_role_type_descriptions1.operation,
           regulation_role_type_descriptions1.operation_date,
           regulation_role_type_descriptions1.filename
          FROM regulation_role_type_descriptions_oplog regulation_role_type_descriptions1
         WHERE ((regulation_role_type_descriptions1.oid IN ( SELECT max(regulation_role_type_descriptions2.oid) AS max
                  FROM regulation_role_type_descriptions_oplog regulation_role_type_descriptions2
                 WHERE ((regulation_role_type_descriptions1.regulation_role_type_id)::text = (regulation_role_type_descriptions2.regulation_role_type_id)::text))) AND ((regulation_role_type_descriptions1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW regulation_role_types AS
        SELECT regulation_role_types1.regulation_role_type_id,
           regulation_role_types1.validity_start_date,
           regulation_role_types1.validity_end_date,
           regulation_role_types1."national",
           regulation_role_types1.oid,
           regulation_role_types1.operation,
           regulation_role_types1.operation_date,
           regulation_role_types1.filename
          FROM regulation_role_types_oplog regulation_role_types1
         WHERE ((regulation_role_types1.oid IN ( SELECT max(regulation_role_types2.oid) AS max
                  FROM regulation_role_types_oplog regulation_role_types2
                 WHERE (regulation_role_types1.regulation_role_type_id = regulation_role_types2.regulation_role_type_id))) AND ((regulation_role_types1.operation)::text <> 'D'::text));

      CREATE OR REPLACE VIEW transmission_comments AS
        SELECT transmission_comments1.comment_sid,
           transmission_comments1.language_id,
           transmission_comments1.comment_text,
           transmission_comments1.oid,
           transmission_comments1.operation,
           transmission_comments1.operation_date,
           transmission_comments1.filename
          FROM transmission_comments_oplog transmission_comments1
         WHERE ((transmission_comments1.oid IN ( SELECT max(transmission_comments2.oid) AS max
                  FROM transmission_comments_oplog transmission_comments2
                 WHERE ((transmission_comments1.comment_sid = transmission_comments2.comment_sid) AND ((transmission_comments1.language_id)::text = (transmission_comments2.language_id)::text)))) AND ((transmission_comments1.operation)::text <> 'D'::text));
    )
  end
end

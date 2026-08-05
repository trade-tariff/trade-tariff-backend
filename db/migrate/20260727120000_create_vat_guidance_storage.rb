# The storage contract requires one migration containing exactly these 11
# append-only tables. They intentionally have creation timestamps only because
# database triggers reject every update.
# rubocop:disable Metrics/BlockLength, Rails/CreateTableWithTimestamps
Sequel.migration do
  up do
    create_table :vat_guides do
      primary_key :id
      String :guide_key, null: false
      String :content_id
      DateTime :created_at, null: false

      index :guide_key, unique: true
      index :content_id, unique: true
    end

    create_table :vat_guide_versions do
      primary_key :id
      foreign_key :guide_id, :vat_guides, null: false, on_delete: :restrict
      String :title, text: true, null: false
      String :canonical_path, text: true, null: false
      String :source_url, text: true, null: false
      String :language, size: 10, null: false
      DateTime :public_updated_at
      DateTime :captured_at, null: false
      String :body_sha256, size: 64, null: false
      Jsonb :sections, null: false, default: Sequel.lit("'[]'::jsonb")
      Jsonb :capture_metadata, null: false, default: Sequel.lit("'{}'::jsonb")
      DateTime :created_at, null: false

      index %i[guide_id body_sha256], unique: true
      index %i[id guide_id], unique: true
      index :body_sha256
    end

    create_table :vat_question_sets do
      primary_key :id
      String :question_set_key, null: false
      String :title, text: true, null: false
      String :root_question_key, null: false
      Jsonb :graph, null: false
      String :content_sha256, size: 64, null: false
      Jsonb :generation_metadata, null: false, default: Sequel.lit("'{}'::jsonb")
      Jsonb :machine_verification_metadata, null: false, default: Sequel.lit("'{}'::jsonb")
      DateTime :created_at, null: false

      index %i[question_set_key content_sha256], unique: true, name: :vat_question_sets_key_content_uidx
      index %i[id question_set_key], unique: true
      index :content_sha256
    end

    create_table :vat_releases do
      primary_key :id
      String :release_key, null: false
      Integer :schema_version, null: false
      Date :tariff_snapshot_as_of, null: false
      Date :supported_start_date, null: false
      Date :supported_end_date
      String :source_snapshot_sha256, size: 64, null: false
      String :tariff_snapshot_sha256, size: 64, null: false
      String :content_sha256, size: 64, null: false
      Integer :guide_count, null: false
      Integer :no_question_guide_count, null: false
      Integer :question_set_count, null: false
      Integer :covered_commodity_count, null: false
      Integer :questions_questionnaire_count, null: false
      Integer :checked_empty_questionnaire_count, null: false
      Integer :commodity_measure_count, null: false
      Integer :link_count, null: false
      String :covered_commodity_list_sha256, size: 64, null: false
      Jsonb :activation_manifest, null: false
      String :signature_algorithm, null: false
      String :signed_payload_sha256, size: 64, null: false
      String :signature, text: true, null: false
      DateTime :generated_at, null: false
      DateTime :created_at, null: false

      index :release_key, unique: true
      index :content_sha256, unique: true
      index %i[supported_start_date supported_end_date]
    end

    create_table :vat_release_guides do
      foreign_key :release_id, :vat_releases, null: false, on_delete: :restrict
      Integer :guide_id, null: false
      Integer :guide_version_id, null: false
      String :analysis_sha256, size: 64, null: false
      String :result, null: false
      DateTime :created_at, null: false

      primary_key %i[release_id guide_id]
      foreign_key %i[guide_version_id guide_id], :vat_guide_versions,
                  key: %i[id guide_id], name: :vat_release_guides_version_guide_fk
      index %i[release_id guide_version_id], unique: true
    end

    create_table :vat_release_question_sets do
      foreign_key :release_id, :vat_releases, null: false, on_delete: :restrict
      String :question_set_key, null: false
      Integer :question_set_id, null: false
      String :verification_sha256, size: 64, null: false
      DateTime :created_at, null: false

      primary_key %i[release_id question_set_key]
      foreign_key %i[question_set_id question_set_key], :vat_question_sets,
                  key: %i[id question_set_key], name: :vat_release_question_sets_version_key_fk
      index %i[release_id question_set_id], unique: true
    end

    create_table :vat_commodity_measures do
      primary_key :id
      foreign_key :release_id, :vat_releases, null: false, on_delete: :restrict
      Integer :measure_sid, null: false
      Integer :goods_nomenclature_sid, null: false
      String :goods_nomenclature_item_id, size: 10, null: false
      String :producline_suffix, size: 2, null: false
      String :outcome_key, null: false
      Date :validity_start_date, null: false
      Date :validity_end_date
      String :content_sha256, size: 64, null: false
      DateTime :created_at, null: false

      index %i[release_id id], unique: true
      index %i[release_id measure_sid goods_nomenclature_sid goods_nomenclature_item_id producline_suffix],
            unique: true,
            name: :vat_commodity_measures_identity_uidx
      index %i[release_id goods_nomenclature_sid]
      index %i[release_id goods_nomenclature_item_id producline_suffix],
            name: :vat_commodity_measures_code_idx
    end

    create_table :vat_question_set_commodity_measures do
      primary_key :id
      Integer :release_id, null: false
      Integer :question_set_id, null: false
      Integer :commodity_measure_id, null: false
      String :outcome_key, null: false
      String :decision_sha256, size: 64, null: false
      Jsonb :evidence_references, null: false, default: Sequel.lit("'[]'::jsonb")
      DateTime :created_at, null: false

      foreign_key %i[release_id question_set_id], :vat_release_question_sets,
                  key: %i[release_id question_set_id], name: :vat_qs_commodity_measures_release_qs_fk
      foreign_key %i[release_id commodity_measure_id], :vat_commodity_measures,
                  key: %i[release_id id], name: :vat_qs_commodity_measures_release_measure_fk
      index %i[release_id question_set_id commodity_measure_id],
            unique: true,
            name: :vat_qs_commodity_measures_identity_uidx
    end

    create_table :vat_commodity_questionnaires do
      primary_key :id
      foreign_key :release_id, :vat_releases, null: false, on_delete: :restrict
      Integer :goods_nomenclature_sid, null: false
      String :goods_nomenclature_item_id, size: 10, null: false
      String :producline_suffix, size: 2, null: false
      String :result_kind, null: false
      Jsonb :expected_vat_options, null: false
      String :membership_order_sha256, size: 64, null: false
      String :assembled_questions_sha256, size: 64, null: false
      DateTime :created_at, null: false

      index %i[release_id id], unique: true
      index %i[release_id goods_nomenclature_sid goods_nomenclature_item_id producline_suffix],
            unique: true,
            name: :vat_commodity_questionnaires_identity_uidx
      index %i[release_id goods_nomenclature_item_id producline_suffix],
            name: :vat_commodity_questionnaires_code_idx
    end

    create_table :vat_commodity_questionnaire_question_sets do
      Integer :release_id, null: false
      Integer :questionnaire_id, null: false
      Integer :question_set_id, null: false
      Integer :position, null: false
      DateTime :created_at, null: false

      primary_key %i[release_id questionnaire_id question_set_id]
      foreign_key %i[release_id questionnaire_id], :vat_commodity_questionnaires,
                  key: %i[release_id id], name: :vat_questionnaire_sets_release_questionnaire_fk
      foreign_key %i[release_id question_set_id], :vat_release_question_sets,
                  key: %i[release_id question_set_id], name: :vat_questionnaire_sets_release_question_set_fk
      index %i[release_id questionnaire_id position],
            unique: true,
            name: :vat_questionnaire_sets_position_uidx
    end

    create_table :vat_release_events do
      primary_key :id
      foreign_key :release_id, :vat_releases, on_delete: :restrict
      String :event_type, null: false
      DateTime :created_at, null: false

      index :created_at
      index %i[release_id created_at]
    end

    run <<~SQL
      ALTER TABLE vat_guide_versions
        ADD CONSTRAINT vat_guide_versions_body_sha256_format
        CHECK (body_sha256 ~ '^[0-9a-f]{64}$'),
        ADD CONSTRAINT vat_guide_versions_sections_array
        CHECK (jsonb_typeof(sections) = 'array'),
        ADD CONSTRAINT vat_guide_versions_capture_metadata_object
        CHECK (jsonb_typeof(capture_metadata) = 'object');

      ALTER TABLE vat_question_sets
        ADD CONSTRAINT vat_question_sets_content_sha256_format
        CHECK (content_sha256 ~ '^[0-9a-f]{64}$'),
        ADD CONSTRAINT vat_question_sets_graph_object
        CHECK (jsonb_typeof(graph) = 'object'),
        ADD CONSTRAINT vat_question_sets_generation_metadata_object
        CHECK (jsonb_typeof(generation_metadata) = 'object'),
        ADD CONSTRAINT vat_question_sets_verification_metadata_object
        CHECK (jsonb_typeof(machine_verification_metadata) = 'object');

      ALTER TABLE vat_releases
        ADD CONSTRAINT vat_releases_supported_dates
        CHECK (supported_end_date IS NULL OR supported_end_date >= supported_start_date),
        ADD CONSTRAINT vat_releases_hash_formats
        CHECK (source_snapshot_sha256 ~ '^[0-9a-f]{64}$'
          AND tariff_snapshot_sha256 ~ '^[0-9a-f]{64}$'
          AND content_sha256 ~ '^[0-9a-f]{64}$'
          AND covered_commodity_list_sha256 ~ '^[0-9a-f]{64}$'
          AND signed_payload_sha256 ~ '^[0-9a-f]{64}$'),
        ADD CONSTRAINT vat_releases_counts_non_negative
        CHECK (guide_count >= 0 AND no_question_guide_count >= 0 AND question_set_count >= 0
          AND covered_commodity_count >= 0 AND questions_questionnaire_count >= 0
          AND checked_empty_questionnaire_count >= 0 AND commodity_measure_count >= 0
          AND link_count >= 0),
        ADD CONSTRAINT vat_releases_activation_manifest_object
        CHECK (jsonb_typeof(activation_manifest) = 'object');

      ALTER TABLE vat_release_guides
        ADD CONSTRAINT vat_release_guides_result
        CHECK (result IN ('questions', 'no_questions')),
        ADD CONSTRAINT vat_release_guides_analysis_sha256_format
        CHECK (analysis_sha256 ~ '^[0-9a-f]{64}$');

      ALTER TABLE vat_release_question_sets
        ADD CONSTRAINT vat_release_question_sets_verification_sha256_format
        CHECK (verification_sha256 ~ '^[0-9a-f]{64}$');

      ALTER TABLE vat_commodity_measures
        ADD CONSTRAINT vat_commodity_measures_code_format
        CHECK (goods_nomenclature_item_id ~ '^[0-9]{10}$'),
        ADD CONSTRAINT vat_commodity_measures_suffix_format
        CHECK (producline_suffix ~ '^[0-9]{2}$'),
        ADD CONSTRAINT vat_commodity_measures_content_sha256_format
        CHECK (content_sha256 ~ '^[0-9a-f]{64}$'),
        ADD CONSTRAINT vat_commodity_measures_validity_dates
        CHECK (validity_end_date IS NULL OR validity_end_date >= validity_start_date);

      ALTER TABLE vat_question_set_commodity_measures
        ADD CONSTRAINT vat_qs_commodity_measures_evidence_array
        CHECK (jsonb_typeof(evidence_references) = 'array'),
        ADD CONSTRAINT vat_qs_commodity_measures_decision_sha256_format
        CHECK (decision_sha256 ~ '^[0-9a-f]{64}$');

      ALTER TABLE vat_commodity_questionnaires
        ADD CONSTRAINT vat_commodity_questionnaires_code_format
        CHECK (goods_nomenclature_item_id ~ '^[0-9]{10}$'),
        ADD CONSTRAINT vat_commodity_questionnaires_suffix_format
        CHECK (producline_suffix ~ '^[0-9]{2}$'),
        ADD CONSTRAINT vat_commodity_questionnaires_result_kind
        CHECK (result_kind IN ('questions', 'checked_empty')),
        ADD CONSTRAINT vat_commodity_questionnaires_options_array
        CHECK (jsonb_typeof(expected_vat_options) = 'array'),
        ADD CONSTRAINT vat_commodity_questionnaires_hash_formats
        CHECK (membership_order_sha256 ~ '^[0-9a-f]{64}$'
          AND assembled_questions_sha256 ~ '^[0-9a-f]{64}$');

      ALTER TABLE vat_commodity_questionnaire_question_sets
        ADD CONSTRAINT vat_questionnaire_sets_positive_position
        CHECK (position > 0);

      ALTER TABLE vat_release_events
        ADD CONSTRAINT vat_release_events_type_and_release
        CHECK ((event_type = 'activate' AND release_id IS NOT NULL)
          OR (event_type = 'disable' AND release_id IS NULL));
    SQL

    run <<~SQL
      CREATE FUNCTION reject_vat_guidance_mutation()
      RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'VAT guidance rows are immutable after insert';
      END;
      $$ LANGUAGE plpgsql;
    SQL

    %i[
      vat_guides
      vat_guide_versions
      vat_question_sets
      vat_releases
      vat_release_guides
      vat_release_question_sets
      vat_commodity_measures
      vat_question_set_commodity_measures
      vat_commodity_questionnaires
      vat_commodity_questionnaire_question_sets
      vat_release_events
    ].each do |table|
      run <<~SQL
        CREATE TRIGGER #{table}_immutable
        BEFORE UPDATE OR DELETE ON #{table}
        FOR EACH ROW EXECUTE FUNCTION reject_vat_guidance_mutation();
      SQL
    end
  end

  down do
    drop_table :vat_release_events
    drop_table :vat_commodity_questionnaire_question_sets
    drop_table :vat_commodity_questionnaires
    drop_table :vat_question_set_commodity_measures
    drop_table :vat_commodity_measures
    drop_table :vat_release_question_sets
    drop_table :vat_release_guides
    drop_table :vat_releases
    drop_table :vat_question_sets
    drop_table :vat_guide_versions
    drop_table :vat_guides
    run 'DROP FUNCTION reject_vat_guidance_mutation()'
  end
end
# rubocop:enable Metrics/BlockLength, Rails/CreateTableWithTimestamps

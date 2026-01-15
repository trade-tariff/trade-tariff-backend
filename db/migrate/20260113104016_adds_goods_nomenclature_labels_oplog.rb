# frozen_string_literal: true

Sequel.migration do
  # NOTE: We're opting for the uk schema, here, to avoid duplication of labels
  # across different schemas (e.g., uk, xi). The Goods Nomenclature entities
  # technically do differ slightly between schemas so there might be some discrepancies.
  #
  # This choice was made because:
  #
  # 1. We don't want to duplicate expensive-to-generate labels across multiple schemas.
  # 2. Our most used schema is 'uk', so it makes sense to centralize there.
  # 3. It simplifies management massively
  # 4. The discrepancies between schemas are minimal for our use case.
  # 5. This avoids conflicts in accessing labels from the different services
  table = Sequel[:goods_nomenclature_labels_oplog].qualify(:uk)
  view = Sequel[:goods_nomenclature_labels].qualify(:uk)

  up do
    unless Sequel::Model.db.table_exists?(table)
      create_table table do
        primary_key :oid

        # --- Logical ID ---
        Integer :goods_nomenclature_sid, null: false

        String  :goods_nomenclature_type, size: 50, null: false
        String  :goods_nomenclature_item_id, size: 10
        String  :producline_suffix, size: 2

        Jsonb :labels, null: false, default: '{}'

        # --- Time Machine ---
        DateTime :validity_start_date, null: false
        DateTime :validity_end_date

        # --- Oplog ---
        String   :operation, size: 1, null: false
        Date     :operation_date, null: false
        DateTime :created_at, null: false
        String   :filename, default: "n/a"

        # --- Indexes ---
        index :goods_nomenclature_sid
        index :created_at, order: :desc
        index :labels, type: :gin
        index [:validity_start_date, :validity_end_date]
      end

      create_view view, <<~EOVIEW, materialized: true
        SELECT o.*
        FROM goods_nomenclature_labels_oplog o
        INNER JOIN (
          SELECT goods_nomenclature_sid, MAX(oid) as max_oid
          FROM goods_nomenclature_labels_oplog
          GROUP BY goods_nomenclature_sid
        ) latest ON o.oid = latest.max_oid
        WHERE o.operation != 'D'; -- Exclude rows where the latest operation was a DELETE
      EOVIEW

      run "CREATE INDEX labels_created_at_idx ON goods_nomenclature_labels (created_at DESC)"
    end
  end

  down do
    if Sequel::Model.db.table_exists?(table)
      drop_view view, materialized: true
      drop_table table
    end
  end
end

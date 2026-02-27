Sequel.migration do
  up do
    current = fetch('SELECT current_schema()').first[:current_schema]

    # Drop the materialized view if it exists on the current schema
    is_matview = fetch(<<~SQL, current).first[:exists]
      SELECT EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = 'goods_nomenclature_labels'
          AND n.nspname = ?
          AND c.relkind = 'm'
      ) AS exists
    SQL

    existing_labels = []

    if is_matview
      view = Sequel[:goods_nomenclature_labels].qualify(current.to_sym)
      existing_labels = from(view).all
      drop_view view, materialized: true
    end

    # Drop oplog table if it exists (always in uk schema)
    oplog_table = Sequel[:goods_nomenclature_labels_oplog].qualify(:uk)
    drop_table(oplog_table) if Sequel::Model.db.table_exists?(oplog_table)

    # Create plain table if absent on current schema
    # Unqualified create_table goes to current schema via search_path
    has_table = fetch(<<~SQL, current).first[:exists]
      SELECT EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = 'goods_nomenclature_labels'
          AND n.nspname = ?
          AND c.relkind = 'r'
      ) AS exists
    SQL

    unless has_table
      create_table :goods_nomenclature_labels do
        Integer   :goods_nomenclature_sid, primary_key: true
        String    :goods_nomenclature_type, size: 50, null: false
        String    :goods_nomenclature_item_id, size: 10, null: false
        String    :producline_suffix, size: 2, null: false
        column    :labels, :jsonb, null: false, default: Sequel.lit("'{}'::jsonb")
        TrueClass :stale, null: false, default: false
        TrueClass :manually_edited, null: false, default: false
        String    :context_hash, size: 64
        DateTime  :created_at, null: false
        DateTime  :updated_at, null: false

        index :goods_nomenclature_item_id
        index :labels, type: :gin
      end

      run 'CREATE INDEX idx_labels_stale ON goods_nomenclature_labels (stale) WHERE stale = TRUE'

      # Copy data from the old materialized view (UK has data, XI starts empty)
      now = Time.now.utc
      existing_labels.each do |row|
        from(:goods_nomenclature_labels).insert(
          goods_nomenclature_sid: row[:goods_nomenclature_sid],
          goods_nomenclature_type: row[:goods_nomenclature_type],
          goods_nomenclature_item_id: row[:goods_nomenclature_item_id],
          producline_suffix: row[:producline_suffix],
          labels: Sequel.pg_jsonb(row[:labels]),
          stale: false,
          manually_edited: false,
          context_hash: nil,
          created_at: row[:created_at] || now,
          updated_at: now,
        )
      end
    end

    # Add search_embedding_stale to self_texts (idempotent)
    unless Sequel::Model.db.schema(:goods_nomenclature_self_texts).any? { |col, _| col == :search_embedding_stale }
      alter_table :goods_nomenclature_self_texts do
        add_column :search_embedding_stale, TrueClass, null: false, default: false
      end

      run 'CREATE INDEX idx_self_texts_search_embedding_stale ON goods_nomenclature_self_texts (search_embedding_stale) WHERE search_embedding_stale = TRUE'
    end
  end

  down do
    drop_table :goods_nomenclature_labels

    alter_table :goods_nomenclature_self_texts do
      drop_column :search_embedding_stale
    end

    # Recreate the oplog table and view (from original migration)
    oplog_table = Sequel[:goods_nomenclature_labels_oplog].qualify(:uk)
    view = Sequel[:goods_nomenclature_labels].qualify(:uk)

    unless Sequel::Model.db.table_exists?(oplog_table)
      create_table oplog_table do
        primary_key :oid

        Integer :goods_nomenclature_sid, null: false
        String  :goods_nomenclature_type, size: 50, null: false
        String  :goods_nomenclature_item_id, size: 10
        String  :producline_suffix, size: 2
        column  :labels, :jsonb, null: false, default: Sequel.lit("'{}'::jsonb")
        DateTime :validity_start_date, null: false
        DateTime :validity_end_date
        String   :operation, size: 1, null: false
        Date     :operation_date, null: false
        DateTime :created_at, null: false
        String   :filename, default: 'n/a'

        index :goods_nomenclature_sid
        index :created_at, order: :desc
        index :labels, type: :gin
        index %i[validity_start_date validity_end_date]
      end

      create_view view, <<~EOVIEW, materialized: true
        SELECT o.*
        FROM uk.goods_nomenclature_labels_oplog o
        INNER JOIN (
          SELECT goods_nomenclature_sid, MAX(oid) as max_oid
          FROM uk.goods_nomenclature_labels_oplog
          GROUP BY goods_nomenclature_sid
        ) latest ON o.oid = latest.max_oid
        WHERE o.operation != 'D';
      EOVIEW

      run "CREATE INDEX labels_created_at_idx ON uk.goods_nomenclature_labels (created_at DESC)"
    end
  end
end

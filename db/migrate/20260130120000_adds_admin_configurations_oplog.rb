# frozen_string_literal: true

Sequel.migration do
  table = Sequel[:admin_configurations_oplog].qualify(:uk)
  view = Sequel[:admin_configurations].qualify(:uk)

  up do
    unless Sequel::Model.db.table_exists?(table)
      create_table table do
        primary_key :oid

        String  :name, null: false
        column  :value, :jsonb, null: false, default: Sequel.lit("'\"\"'::jsonb")
        String  :config_type, size: 50, null: false
        String  :area, size: 50, null: false, default: 'classification'
        String  :description, text: true

        # Oplog columns
        String   :operation, size: 1, null: false
        Date     :operation_date, null: false
        DateTime :created_at, null: false

        index :name
        index :area
        index [:name, Sequel.desc(:oid)]
      end

      create_view view, <<~EOVIEW, materialized: true
        SELECT o.*
        FROM uk.admin_configurations_oplog o
        INNER JOIN (
          SELECT name, MAX(oid) as max_oid
          FROM uk.admin_configurations_oplog
          GROUP BY name
        ) latest ON o.oid = latest.max_oid
        WHERE o.operation != 'D';
      EOVIEW

      run 'CREATE UNIQUE INDEX idx_ac_mv_name ON uk.admin_configurations (name)'
      run 'CREATE INDEX idx_ac_mv_area ON uk.admin_configurations (area)'
      run 'CREATE INDEX idx_ac_mv_value_gin ON uk.admin_configurations USING gin (value)'
    end
  end

  down do
    if Sequel::Model.db.table_exists?(table)
      drop_view view, materialized: true
      drop_table table
    end
  end
end

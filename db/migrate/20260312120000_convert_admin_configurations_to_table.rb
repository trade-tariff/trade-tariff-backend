# frozen_string_literal: true

Sequel.migration do
  oplog = Sequel[:admin_configurations_oplog].qualify(:uk)
  view = Sequel[:admin_configurations].qualify(:uk)
  table = Sequel[:admin_configurations].qualify(:uk)

  up do
    next unless TradeTariffBackend.uk?

    # 1. Drop the materialized view
    drop_view view, materialized: true

    # 2. Create a regular table
    create_table table do
      primary_key :id

      String  :name, null: false, unique: true
      column  :value, :jsonb, null: false, default: Sequel.lit("'\"\"'::jsonb")
      String  :config_type, size: 50, null: false
      String  :area, size: 50, null: false, default: 'classification'
      String  :description, text: true
      DateTime :created_at, null: false, default: Sequel.lit('CURRENT_TIMESTAMP')
      DateTime :updated_at, null: false, default: Sequel.lit('CURRENT_TIMESTAMP')

      index :name, unique: true, name: :idx_ac_name
      index :area, name: :idx_ac_area
    end

    # 3. Migrate current data from the oplog (latest version of each config)
    run <<~SQL
      INSERT INTO uk.admin_configurations (name, value, config_type, area, description, created_at, updated_at)
      SELECT o.name, o.value, o.config_type, o.area, o.description, o.created_at, o.created_at
      FROM uk.admin_configurations_oplog o
      INNER JOIN (
        SELECT name, MAX(oid) as max_oid
        FROM uk.admin_configurations_oplog
        GROUP BY name
      ) latest ON o.oid = latest.max_oid
      WHERE o.operation != 'D'
    SQL

    # 4. Drop the oplog table
    drop_table oplog
  end

  down do
    next unless TradeTariffBackend.uk?

    # Recreate oplog table and materialized view
    create_table oplog do
      primary_key :oid

      String  :name, null: false
      column  :value, :jsonb, null: false, default: Sequel.lit("'\"\"'::jsonb")
      String  :config_type, size: 50, null: false
      String  :area, size: 50, null: false, default: 'classification'
      String  :description, text: true

      String   :operation, size: 1, null: false
      Date     :operation_date, null: false
      DateTime :created_at, null: false

      index :name
      index :area
      index [:name, Sequel.desc(:oid)]
    end

    # Seed oplog from current table data
    run <<~SQL
      INSERT INTO uk.admin_configurations_oplog (name, value, config_type, area, description, operation, operation_date, created_at)
      SELECT name, value, config_type, area, description, 'C', CURRENT_DATE, created_at
      FROM uk.admin_configurations
    SQL

    # Drop the regular table and recreate as materialized view
    drop_table table

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

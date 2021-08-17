class MeursingTablePlan < Sequel::Model
  plugin :oplog, primary_key: :meursing_table_plan_id

  set_primary_key [:meursing_table_plan_id]
end

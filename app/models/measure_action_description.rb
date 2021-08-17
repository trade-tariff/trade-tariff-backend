class MeasureActionDescription < Sequel::Model
  plugin :oplog, primary_key: :action_code

  set_primary_key [:action_code]
end

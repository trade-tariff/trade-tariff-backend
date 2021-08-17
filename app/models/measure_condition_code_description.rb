class MeasureConditionCodeDescription < Sequel::Model
  plugin :oplog, primary_key: :condition_code

  set_primary_key [:condition_code]
end

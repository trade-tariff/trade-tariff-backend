class RegulationGroupDescription < Sequel::Model
  plugin :oplog, primary_key: :regulation_group_id

  set_primary_key [:regulation_group_id]
end

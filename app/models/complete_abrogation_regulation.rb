class CompleteAbrogationRegulation < Sequel::Model
  set_primary_key %i[complete_abrogation_regulation_id complete_abrogation_regulation_role]

  plugin :oplog, primary_key: %i[complete_abrogation_regulation_id complete_abrogation_regulation_role]
end

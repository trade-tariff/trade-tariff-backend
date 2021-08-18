class RegulationReplacement < Sequel::Model
  plugin :oplog, primary_key: %i[replacing_regulation_id
                                 replacing_regulation_role
                                 replaced_regulation_id
                                 replaced_regulation_role]

  set_primary_key %i[replacing_regulation_id replacing_regulation_role
                     replaced_regulation_id replaced_regulation_role]
end

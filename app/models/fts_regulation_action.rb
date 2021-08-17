class FtsRegulationAction < Sequel::Model
  plugin :oplog, primary_key: %i[fts_regulation_id
                                 fts_regulation_role
                                 stopped_regulation_id
                                 stopped_regulation_role]

  set_primary_key %i[fts_regulation_id fts_regulation_role
                     stopped_regulation_id stopped_regulation_role]
end

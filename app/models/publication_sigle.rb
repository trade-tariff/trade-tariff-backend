class PublicationSigle < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: %i[oid code code_type_id]

  set_primary_key %i[code code_type_id]
end

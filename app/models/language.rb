class Language < Sequel::Model
  plugin :oplog, primary_key: :language_id

  set_primary_key [:language_id]
end

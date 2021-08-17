class FootnoteTypeDescription < Sequel::Model
  plugin :oplog, primary_key: :footnote_type_id

  set_primary_key [:footnote_type_id]
end

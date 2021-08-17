class FootnoteAssociationAdditionalCode < Sequel::Model
  plugin :oplog, primary_key: %i[footnote_id
                                 footnote_type_id
                                 additional_code_sid]
  set_primary_key %i[footnote_id footnote_type_id additional_code_sid]
end

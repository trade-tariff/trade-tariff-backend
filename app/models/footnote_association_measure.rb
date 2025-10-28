class FootnoteAssociationMeasure < Sequel::Model
  set_primary_key %i[measure_sid footnote_id footnote_type_id]
  plugin :oplog, primary_key: %i[measure_sid
                                 footnote_id
                                 footnote_type_id]

  one_to_one :footnote, key: %i[footnote_id footnote_type_id],
                        primary_key: %i[footnote_id footnote_type_id]
  one_to_one :measure, key: :measure_sid,
                       primary_key: :measure_sid
end

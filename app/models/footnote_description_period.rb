class FootnoteDescriptionPeriod < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: %i[footnote_id
                                 footnote_type_id
                                 footnote_description_period_sid]

  set_primary_key %i[footnote_id footnote_type_id footnote_description_period_sid]

  one_to_one :footnote_description, key: %i[footnote_id
                                            footnote_type_id
                                            footnote_description_period_sid]
end

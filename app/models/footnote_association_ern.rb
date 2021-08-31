class FootnoteAssociationErn < Sequel::Model
  plugin :oplog, primary_key: %i[export_refund_nomenclature_sid
                                 footnote_id
                                 footnote_type
                                 validity_start_date]

  set_primary_key %i[export_refund_nomenclature_sid
                     footnote_id
                     footnote_type
                     validity_start_date]
end

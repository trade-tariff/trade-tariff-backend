class FootnoteAssociationGoodsNomenclature < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: %i[footnote_id
                                 footnote_type
                                 goods_nomenclature_sid]

  set_primary_key %i[footnote_id footnote_type goods_nomenclature_sid]
end

class FootnoteAssociationGoodsNomenclature < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: %i[footnote_id
                                 footnote_type
                                 goods_nomenclature_sid]

  set_primary_key %i[footnote_id footnote_type goods_nomenclature_sid]

  one_to_one :footnote, key: %i[footnote_id footnote_type_id],
                        primary_key: %i[footnote_id footnote_type]
  one_to_one :goods_nomenclature, key: :goods_nomenclature_sid,
                                  primary_key: :goods_nomenclature_sid
end

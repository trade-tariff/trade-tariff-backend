class FootnoteAssociationGoodsNomenclature < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: %i[footnote_id
                                 footnote_type
                                 goods_nomenclature_sid]

  set_primary_key %i[footnote_id footnote_type goods_nomenclature_sid]

  def self.associate_footnote_with_goods_nomenclature(goods_nomenclature, footnote)
    f = FootnoteAssociationGoodsNomenclature.new
    f.values[:goods_nomenclature_sid] = goods_nomenclature.values[:goods_nomenclature_sid]
    f.values[:goods_nomenclature_item_id] = goods_nomenclature.values[:goods_nomenclature_item_id]
    f.values[:productline_suffix] = goods_nomenclature.values[:producline_suffix]
    f.values[:validity_start_date] = goods_nomenclature.values[:validity_start_date]
    f.values[:validity_end_date] = goods_nomenclature.values[:validity_end_date]
    f.values[:operation] = goods_nomenclature.values[:operation]
    f.values[:footnote_id] = footnote.values[:footnote_id]
    f.values[:footnote_type] = footnote.values[:footnote_type_id]
    f.values[:national] = footnote.values[:national]
    f.save
  end
end

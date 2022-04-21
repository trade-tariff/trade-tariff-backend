TradeTariffBackend::DataMigrator.migration do
  name 'End 05044 footnote for 7304293080 commodity'

  FOOTNOTE_ID = '004'.freeze
  FOOTNOTE_TYPE = '05'.freeze
  GOODS_NOMENCLATURE_ITEM_ID = '7304293080'.freeze
  VALIDITY_END_DATE = Date.new(2020, 5, 16)

  up do
    applicable do
      FootnoteAssociationGoodsNomenclature.where(
        footnote_id: FOOTNOTE_ID,
        footnote_type: FOOTNOTE_TYPE,
        goods_nomenclature_item_id: GOODS_NOMENCLATURE_ITEM_ID
      ).where('validity_end_date <> ? OR validity_end_date IS NULL', VALIDITY_END_DATE).any?
      false
    end

    apply do
      FootnoteAssociationGoodsNomenclature.where(
        footnote_id: FOOTNOTE_ID,
        footnote_type: FOOTNOTE_TYPE,
        goods_nomenclature_item_id: GOODS_NOMENCLATURE_ITEM_ID
      ).where('validity_end_date <> ? OR validity_end_date IS NULL', VALIDITY_END_DATE).each do |association|
        association.update(validity_end_date: VALIDITY_END_DATE)
      end
    end
  end

  down do
    applicable do
      FootnoteAssociationGoodsNomenclature.where(
        footnote_id: FOOTNOTE_ID,
        footnote_type: FOOTNOTE_TYPE,
        goods_nomenclature_item_id: GOODS_NOMENCLATURE_ITEM_ID,
        validity_end_date: VALIDITY_END_DATE
      ).any?
      false
    end

    apply do
      FootnoteAssociationGoodsNomenclature::Operation.where(
        footnote_id: FOOTNOTE_ID,
        footnote_type: FOOTNOTE_TYPE,
        goods_nomenclature_item_id: GOODS_NOMENCLATURE_ITEM_ID,
        validity_end_date: VALIDITY_END_DATE,
        operation: 'U'
      ).delete
    end
  end
end

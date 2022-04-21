TradeTariffBackend::DataMigrator.migration do
  name "End national footnote 05_014"

  FOOTNOTE_TYPE_ID = '05'
  FOOTNOTE_ID = '014'
  VALIDITY_END_DATE = Date.new(2017, 03, 01)


  up do
    applicable {
      Footnote::Operation.where(
        footnote_type_id: FOOTNOTE_TYPE_ID,
        footnote_id: FOOTNOTE_ID,
        validity_end_date: VALIDITY_END_DATE
      ).count == 0
      false
    }

    apply {
      Footnote.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).where('validity_end_date <> ? OR validity_end_date IS NULL', VALIDITY_END_DATE).all.each do |f|
        f.update(validity_end_date: VALIDITY_END_DATE)
      end

      FootnoteDescriptionPeriod.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).where('validity_end_date <> ? OR validity_end_date IS NULL', VALIDITY_END_DATE).all.each do |fdp|
        fdp.update(validity_end_date: VALIDITY_END_DATE)
      end

      FootnoteAssociationAdditionalCode.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).where('validity_end_date <> ? OR validity_end_date IS NULL', VALIDITY_END_DATE).all.each do |faac|
        faac.update(validity_end_date: VALIDITY_END_DATE)
      end

      FootnoteAssociationGoodsNomenclature.where(footnote_type: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).where('validity_end_date <> ? OR validity_end_date IS NULL', VALIDITY_END_DATE).all.each do |fagn|
        fagn.update(validity_end_date: VALIDITY_END_DATE)
      end

      FootnoteAssociationMeursingHeading.where(footnote_type: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).where('validity_end_date <> ? OR validity_end_date IS NULL', VALIDITY_END_DATE).all.each do |famh|
        famh.update(validity_end_date: VALIDITY_END_DATE)
      end

      FootnoteAssociationErn.where(footnote_type: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).where('validity_end_date <> ? OR validity_end_date IS NULL', VALIDITY_END_DATE).all.each do |fae|
        fae.update(validity_end_date: VALIDITY_END_DATE)
      end
    }
  end

  down do
    applicable {
      Footnote::Operation.where(
        footnote_type_id: FOOTNOTE_TYPE_ID,
        footnote_id: FOOTNOTE_ID,
        validity_end_date: VALIDITY_END_DATE
      ).count > 0
      false
    }

    apply {
      Footnote::Operation.where(
        footnote_type_id: FOOTNOTE_TYPE_ID,
        footnote_id: FOOTNOTE_ID,
        validity_end_date: VALIDITY_END_DATE,
        operation: 'U'
      ).delete
      FootnoteDescriptionPeriod::Operation.where(
        footnote_type_id: FOOTNOTE_TYPE_ID,
        footnote_id: FOOTNOTE_ID,
        validity_end_date: VALIDITY_END_DATE,
        operation: 'U'
      ).delete
      FootnoteAssociationAdditionalCode::Operation.where(
        footnote_type_id: FOOTNOTE_TYPE_ID,
        footnote_id: FOOTNOTE_ID,
        validity_end_date: VALIDITY_END_DATE,
        operation: 'U'
      ).delete
      FootnoteAssociationGoodsNomenclature::Operation.where(
        footnote_type: FOOTNOTE_TYPE_ID,
        footnote_id: FOOTNOTE_ID,
        validity_end_date: VALIDITY_END_DATE,
        operation: 'U'
      ).delete
      FootnoteAssociationMeursingHeading::Operation.where(
        footnote_type: FOOTNOTE_TYPE_ID,
        footnote_id: FOOTNOTE_ID,
        validity_end_date: VALIDITY_END_DATE,
        operation: 'U'
      ).delete
      FootnoteAssociationErn::Operation.where(
        footnote_type: FOOTNOTE_TYPE_ID,
        footnote_id: FOOTNOTE_ID,
        validity_end_date: VALIDITY_END_DATE,
        operation: 'U'
      ).delete
    }
  end
end

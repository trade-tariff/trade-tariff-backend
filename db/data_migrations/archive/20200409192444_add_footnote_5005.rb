TradeTariffBackend::DataMigrator.migration do
  name "Create new footnote 05005"

  FOOTNOTE_ID = "005"
  FOOTNOTE_TYPE_ID = "05"
  FOOTNOTE_DESCRIPTION = "
    <p>The exportation of certain COVID 19 related Personal Protective Equipment : Integration of regulation 2020/426</p>

    <p>For further information:</p>

    <p>
      Some of the goods contained in this commodity code fall under EU Regulation 2020/402 of 14 March 2020.
      This makes the exportation of certain COVID 19 related Personal Protective Equipment subject to an export authorisation.
      If your goods are described in Annex I of this regulation, you cannot export them without a licence.
      Guidance on the regulation, which goods are controlled and how to apply for a licence is available
      at <a href=\"https://www.gov.uk/government/publications/personal-protective-equipment-ppe-export-control-process/personal-protective-equipment-ppe-export-control-process\">
           https://www.gov.uk/government/publications/personal-protective-equipment-ppe-export-control-process/personal-protective-equipment-ppe-export-control-process
      </a>.
    </p>".squish
  VALIDITY_START_DATE = Date.new(1971,12,31)
  FOOTNOTE_DESCRIPTION_PERIOD_SID = -219

  up do
    applicable { false }
    apply {
      create_footnote
      create_footnote_description_period
      create_footnote_description
      create_footnote_association_goods_nomenclature
    }
  end

  down do
    applicable { false }
    apply {
      Footnote::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).delete
      FootnoteDescription::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).delete
      FootnoteDescriptionPeriod::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).delete
      FootnoteAssociationGoodsNomenclature::Operation.where(footnote_type: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).delete
    }
  end

  def create_footnote
    if Footnote.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).none?
      Footnote.new { |f|
        f.footnote_type_id = FOOTNOTE_TYPE_ID
        f.footnote_id = FOOTNOTE_ID
        f.national = true
        f.validity_start_date = VALIDITY_START_DATE
        f.operation_date = VALIDITY_START_DATE
      }.save
    end
  end

  def create_footnote_description
    if FootnoteDescription.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).none?
      FootnoteDescription.new { |fd|
        fd.footnote_description_period_sid = FOOTNOTE_DESCRIPTION_PERIOD_SID
        fd.language_id = 'EN'
        fd.footnote_type_id = FOOTNOTE_TYPE_ID
        fd.footnote_id = FOOTNOTE_ID
        fd.national = true
        fd.description = FOOTNOTE_DESCRIPTION
        fd.operation_date = VALIDITY_START_DATE
      }.save
    end
  end

  def create_footnote_description_period
    if FootnoteDescriptionPeriod.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).none?
      FootnoteDescriptionPeriod.new { |fdp|
        fdp.footnote_description_period_sid = FOOTNOTE_DESCRIPTION_PERIOD_SID
        fdp.footnote_type_id = FOOTNOTE_TYPE_ID
        fdp.footnote_id = FOOTNOTE_ID
        fdp.validity_start_date = VALIDITY_START_DATE
        fdp.national = true
        fdp.operation_date = VALIDITY_START_DATE
      }.save
    end
  end

  def create_footnote_association_goods_nomenclature
    footnote = Footnote.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).last

    codes = ["3926200000", "4015900000", "6113001000", "6113009000", "6114200000", "6114300000", "6114900000",
             "6210101000", "6210109200", "6210109800", "6210200000", "6210300000", "6210400000", "6210500000",
             "6211321000", "6211329000", "6211331000", "6211339000", "6211390000", "6211421000", "6211429000",
             "6211431000", "6211439000", "6211490000", "6307909800", "9004901000", "9004909000"]

    GoodsNomenclature.where(goods_nomenclature_item_id: codes).each do |goods_nomenclature|
      if FootnoteAssociationGoodsNomenclature.where(goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id, footnote_id: FOOTNOTE_ID, footnote_type: FOOTNOTE_TYPE_ID).none?
        FootnoteAssociationGoodsNomenclature.associate_footnote_with_goods_nomenclature(goods_nomenclature, footnote)
      end
    end
  end
end

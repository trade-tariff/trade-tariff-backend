TradeTariffBackend::DataMigrator.migration do
  name "Add hydrocarbon oils footnote 05976"

  ASSOCIATED_GOODS_CODES = %w[
    3826001010
    3826001090
    3826009011
    3826009019
    3826009030
    3826009090
  ]

  up do
    applicable {
      Footnote::Operation.where(footnote_type_id: '05', footnote_id: '976').none? ||
      FootnoteDescription::Operation.where(footnote_type_id: '05', footnote_id: '976').none? ||
      FootnoteDescriptionPeriod::Operation.where(footnote_type_id: '05', footnote_id: '976').none? ||
      FootnoteAssociationGoodsNomenclature::Operation.where(
        footnote_type: '05',
        footnote_id: '976',
        goods_nomenclature_item_id: ASSOCIATED_GOODS_CODES
      ).count != ASSOCIATED_GOODS_CODES.size
      false
    }

    apply {
      # make the run idempotent, delete records first if they exist
      Footnote::Operation.where(footnote_type_id: '05', footnote_id: '976').delete
      FootnoteDescription::Operation.where(footnote_type_id: '05', footnote_id: '976').delete
      FootnoteDescriptionPeriod::Operation.where(footnote_type_id: '05', footnote_id: '976').delete
      FootnoteAssociationGoodsNomenclature::Operation.where(footnote_type: '05', footnote_id: '976').delete

      Footnote.new { |f|
        f.footnote_type_id = '05'
        f.footnote_id = '976'
        f.national = true
        f.validity_start_date = Date.new(1971,12,31)
      }.save

      FootnoteDescriptionPeriod.new { |fdp|
        fdp.footnote_description_period_sid = -216
        fdp.footnote_type_id = '05'
        fdp.footnote_id = '976'
        fdp.validity_start_date = Date.new(1971,12,31)
        fdp.national = true
      }.save

      FootnoteDescription.new { |fd|
        fd.footnote_description_period_sid = -216
        fd.language_id = 'EN'
        fd.footnote_type_id = '05'
        fd.footnote_id = '976'
        fd.national = true
        fd.description = 'Goods under this heading may be liable to Hydrocarbon Oils duty - see Volume 1, Part 12, para 12.15'
      }.save

      ASSOCIATED_GOODS_CODES.each do |goods_code|
        FootnoteAssociationGoodsNomenclature.new { |fagono|
          fagono.goods_nomenclature_sid = TimeMachine.now {
            commodity = Commodity.actual.declarable.by_code(goods_code).take
            commodity.goods_nomenclature_sid
          }
          fagono.goods_nomenclature_item_id = goods_code
          fagono.productline_suffix = 80 # declarable goods code
          fagono.validity_end_date = nil
          fagono.footnote_type = '05'
          fagono.footnote_id = '976'
          fagono.national = true
          fagono.validity_start_date = Date.new(1971,12,31)
        }.save
      end
    }
  end

  down do
    applicable {
      Footnote::Operation.where(footnote_type_id: '05', footnote_id: '976').present? ||
      FootnoteDescription::Operation.where(footnote_type_id: '05', footnote_id: '976').present? ||
      FootnoteDescriptionPeriod::Operation.where(footnote_type_id: '05', footnote_id: '976').present? ||
      FootnoteAssociationGoodsNomenclature::Operation.where(footnote_type: '05', footnote_id: '976').present?
      false
    }

    apply {
      Footnote::Operation.where(footnote_type_id: '05', footnote_id: '976').delete
      FootnoteDescription::Operation.where(footnote_type_id: '05', footnote_id: '976').delete
      FootnoteDescriptionPeriod::Operation.where(footnote_type_id: '05', footnote_id: '976').delete
      FootnoteAssociationGoodsNomenclature::Operation.where(footnote_type: '05', footnote_id: '976').delete
    }
  end
end

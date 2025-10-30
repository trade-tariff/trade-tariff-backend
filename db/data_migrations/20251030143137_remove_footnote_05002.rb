FOOTNOTE_TYPE_ID = '05'.freeze
FOOTNOTE_ID = '002'.freeze

Sequel.migration do
  up do
    if TradeTariffBackend.xi?
      Footnote::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).delete
      FootnoteDescriptionPeriod::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).delete
      FootnoteDescription::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).delete

      Sequel::Model.db[:footnote_association_goods_nomenclatures_oplog]
                   .where(
                     footnote_type: FOOTNOTE_TYPE_ID,
                     footnote_id: FOOTNOTE_ID,
                   ).delete

    end
  end

  down do
    # Irreversible!
  end
end

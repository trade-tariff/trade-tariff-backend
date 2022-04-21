TradeTariffBackend::DataMigrator.migration do
  name "Add national footnote"

  FOOTNOTE_TYPE_ID = "05"
  FOOTNOTE_ID = "014"
  FOOTNOTE_DESCRIPTION = "Where the free rate of duty has been applied due to inclusion of 'Multi-component integrated circuits' (MCOs) document code Y035 (no status or reference required) must be declared at item level in box 44."
  VALIDITY_START_DATE = Date.new(2016, 9, 8)

  def delete_footnote_and_associations
    Footnote::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).delete
    FootnoteDescription::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).delete
    FootnoteDescriptionPeriod::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).delete
    FootnoteAssociationGoodsNomenclature::Operation.where(footnote_type: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).delete
  end

  up do
    applicable {
      Footnote.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).none? ||
      FootnoteDescription.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID, description: FOOTNOTE_DESCRIPTION).none? ||
      FootnoteDescriptionPeriod.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).none?
      false
    }

    apply {
      # make the run idempotent, delete records first if they exist
      delete_footnote_and_associations

      Footnote.new { |f|
        f.footnote_type_id = FOOTNOTE_TYPE_ID
        f.footnote_id = FOOTNOTE_ID
        f.national = true
        f.validity_start_date = VALIDITY_START_DATE
        f.operation_date = nil # as it came from initial import
      }.save

      FootnoteDescriptionPeriod.new { |fdp|
        fdp.footnote_description_period_sid = -218
        fdp.footnote_type_id = FOOTNOTE_TYPE_ID
        fdp.footnote_id = FOOTNOTE_ID
        fdp.validity_start_date = VALIDITY_START_DATE
        fdp.national = true
        fdp.operation_date = nil # as it came from initial import
      }.save

      FootnoteDescription.new { |fd|
        fd.footnote_description_period_sid = -218
        fd.language_id = "EN"
        fd.footnote_type_id = FOOTNOTE_TYPE_ID
        fd.footnote_id = FOOTNOTE_ID
        fd.national = true
        fd.description = FOOTNOTE_DESCRIPTION
        fd.operation_date = nil # as it came from initial import
      }.save
    }
  end

  down do
    applicable {
      Footnote.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).any? ||
      FootnoteDescription.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).any? ||
      FootnoteDescriptionPeriod.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).any? ||
      FootnoteAssociationGoodsNomenclature.where(footnote_type: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).any?
      false
    }

    apply {
      delete_footnote_and_associations
    }
  end
end

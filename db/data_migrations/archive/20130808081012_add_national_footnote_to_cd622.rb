TradeTariffBackend::DataMigrator.migration do
  name "Add national footnote to Taric's CD662"

  FOOTNOTE_TYPE_ID = '06'
  FOOTNOTE_ID = '013'
  FOOTNOTE_DESCRIPTION = "Due to CHIEF being unable to process an additional code with two different duty rates, imports should be declared under the same numeric additional codes but replacing the 'B' with an 'X', to obtain exemption from the anti-dumping duty where the conditions under footnote CD662 are met."

  TARIC_FOOTNOTE_TYPE_ID = 'CD'
  TARIC_FOOTNOTE_ID = '662'

  VALIDITY_START_DATE = Date.new(2013,8,6)

  GOODS_NOMENCLATURE_ITEM_IDS = %w[
    3818001011
    3818001019
    8541409021
    8541409029
    8541409031
    8541409039
  ]

  def delete_footnote_and_associations
    Footnote::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).delete
    FootnoteDescription::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).delete
    FootnoteDescriptionPeriod::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).delete
    FootnoteAssociationMeasure::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).delete
  end

  up do
    applicable {
      taric_footnote_count = FootnoteAssociationMeasure.where(
        footnote_type_id: TARIC_FOOTNOTE_TYPE_ID,
        footnote_id: TARIC_FOOTNOTE_ID
      ).count

      chief_footnote_count = FootnoteAssociationMeasure.where(
        footnote_type_id: FOOTNOTE_TYPE_ID,
        footnote_id: FOOTNOTE_ID
      ).count

      Footnote::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).none? ||
      FootnoteDescription::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID, description: FOOTNOTE_DESCRIPTION).none? ||
      FootnoteDescriptionPeriod::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).none? ||
      taric_footnote_count != chief_footnote_count
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
        fdp.footnote_description_period_sid = -217
        fdp.footnote_type_id = FOOTNOTE_TYPE_ID
        fdp.footnote_id = FOOTNOTE_ID
        fdp.validity_start_date = VALIDITY_START_DATE
        fdp.national = true
        fdp.operation_date = nil # as it came from initial import
      }.save

      FootnoteDescription.new { |fd|
        fd.footnote_description_period_sid = -217
        fd.language_id = 'EN'
        fd.footnote_type_id = FOOTNOTE_TYPE_ID
        fd.footnote_id = FOOTNOTE_ID
        fd.national = true
        fd.description = FOOTNOTE_DESCRIPTION
        fd.operation_date = nil # as it came from initial import
      }.save

      FootnoteAssociationMeasure.where(
        footnote_type_id: TARIC_FOOTNOTE_TYPE_ID,
        footnote_id: TARIC_FOOTNOTE_ID
      ).join(
        :measures,
        { footnote_association_measures__measure_sid: :measures__measure_sid }
      ).where(
        measures__goods_nomenclature_item_id: GOODS_NOMENCLATURE_ITEM_IDS
      ).each { |measure_association|
        FootnoteAssociationMeasure.new { |fa_meas|
          fa_meas.measure_sid = measure_association.measure_sid
          fa_meas.footnote_type_id = FOOTNOTE_TYPE_ID
          fa_meas.footnote_id = FOOTNOTE_ID
          fa_meas.national = true
          fa_meas.operation_date = nil # as it came from initial import
        }.save
      }
    }
  end

  down do
    applicable {
      Footnote::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).any? ||
      FootnoteDescription::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).any? ||
      FootnoteDescriptionPeriod::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).any? ||
      FootnoteAssociationMeasure::Operation.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).any?
      false
    }

    apply {
      delete_footnote_and_associations
    }
  end
end

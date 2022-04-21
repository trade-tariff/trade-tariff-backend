TradeTariffBackend::DataMigrator.migration do
  name "Fix National Country Group names"

  DTI_LIC_TEXT = 'DTI LIC'
  DPO_TEXTILES_TEXT = 'DPO Textiles'
  PRECURSOR_DRUG_TEXT = 'Home Office - Precursor Drugs Licensing - Exports'

  up do
    applicable {
      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'B069',
        description: DTI_LIC_TEXT
      ).none? ||
      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'B110',
        description: DPO_TEXTILES_TEXT
      ).none? ||
      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'D010',
        description: PRECURSOR_DRUG_TEXT
      ).none? ||
      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'D063',
        description: PRECURSOR_DRUG_TEXT
      ).none? ||
      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'D064',
        description: PRECURSOR_DRUG_TEXT
      ).none? ||
      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'D065',
        description: PRECURSOR_DRUG_TEXT
      ).none?
      false
    }

    apply {
      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'B069',
      ).update(
        description: DTI_LIC_TEXT
      )

      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'B110',
      ).update(
        description: DPO_TEXTILES_TEXT
      )

      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'D010',
      ).update(
        description: PRECURSOR_DRUG_TEXT
      )

      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'D063',
      ).update(
        description: PRECURSOR_DRUG_TEXT
      )

      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'D064',
      ).update(
        description: PRECURSOR_DRUG_TEXT
      )

      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'D065',
      ).update(
        description: PRECURSOR_DRUG_TEXT
      )
    }
  end

  down do
    applicable {
      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'B069',
        description: DTI_LIC_TEXT
      ).any? ||
      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'B110',
        description: DPO_TEXTILES_TEXT
      ).any? ||
      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'D010',
        description: PRECURSOR_DRUG_TEXT
      ).any? ||
      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'D063',
        description: PRECURSOR_DRUG_TEXT
      ).any? ||
      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'D064',
        description: PRECURSOR_DRUG_TEXT
      ).any? ||
      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'D065',
        description: PRECURSOR_DRUG_TEXT
      ).any?
      false
    }

    apply {
      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'B069',
      ).update(
        description: nil
      )

      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'B110',
      ).update(
        description: nil
      )

      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'D010',
      ).update(
        description: nil
      )

      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'D063',
      ).update(
        description: nil
      )

      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'D064',
      ).update(
        description: nil
      )

      GeographicalAreaDescription::Operation.where(
        geographical_area_id: 'D065',
      ).update(
        description: nil
      )
    }
  end
end

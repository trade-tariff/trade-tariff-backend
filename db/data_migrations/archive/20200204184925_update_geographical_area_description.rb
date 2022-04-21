TradeTariffBackend::DataMigrator.migration do
  name "Manual update of the description of the geographical area F006"

  GEOGRAPHICAL_AREA_ID = "F006"
  OLD_DESCRIPTION = nil
  NEW_DESCRIPTION = "Common Agricultural Policy and Rural Payments Agency"

  up do
    applicable {
      GeographicalAreaDescription.where(geographical_area_id: GEOGRAPHICAL_AREA_ID, description: OLD_DESCRIPTION).any?
      false
    }

    apply {
      description = GeographicalAreaDescription.where(geographical_area_id: GEOGRAPHICAL_AREA_ID, description: OLD_DESCRIPTION).last
      description.update(description: NEW_DESCRIPTION)
    }
  end

  down do
    applicable { false }
    apply { }
  end
end

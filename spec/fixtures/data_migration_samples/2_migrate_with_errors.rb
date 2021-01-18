TradeTariffBackend::DataMigrator.migration do
  name 'Migrate with errors'

  up do
    applicable   { Language.dataset.none? }
    apply        do
      Language.unrestrict_primary_key
      Language.create(language_id: 'GB')
      Language.create(language_id: 'ES')
      Language.restrict_primary_key
    end
  end

  down do
    applicable {}
    apply {}
  end
end

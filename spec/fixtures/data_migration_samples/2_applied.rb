TradeTariffBackend::DataMigrator.migration do
  name 'Applied Other'

  up do
    applicable   { Language.dataset.where(language_id: 'US').last.nil? }
    apply        do
      Language.unrestrict_primary_key
      Language.create(language_id: 'US')
    end
  end

  down do
    applicable { Language.dataset.where(language_id: 'US').any? }
    apply { Language.dataset.where(language_id: 'US').destroy }
  end
end

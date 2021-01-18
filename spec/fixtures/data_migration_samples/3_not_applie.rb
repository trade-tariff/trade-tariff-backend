TradeTariffBackend::DataMigrator.migration do
  name 'Not Applied'

  up do
    applicable   { Language.dataset.where(language_id: 'RU').last.nil? }
    apply        do
      Language.unrestrict_primary_key
      Language.create(language_id: 'RU')
    end
  end

  down do
    applicable { Language.dataset.where(language_id: 'RU').any? }
    apply { Language.dataset.where(language_id: 'US').destroy }
  end
end

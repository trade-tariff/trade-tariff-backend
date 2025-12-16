# frozen_string_literal: true

Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      puts "Deleting all TariffChange records"
      from(:tariff_changes).delete

      TariffChangesService.generate
    end
  end
end

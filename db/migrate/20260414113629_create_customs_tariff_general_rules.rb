Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      create_table :customs_tariff_general_rules do
        primary_key :id
        String :customs_tariff_update_version, null: false
        String :rule_label, size: 10, null: false
        String :content, text: true, null: false

        index %i[customs_tariff_update_version rule_label], unique: true
      end
    end
  end

  down do
    drop_table :customs_tariff_general_rules
  end
end

Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      create_table :customs_tariff_section_notes do
        primary_key :id
        String :customs_tariff_update_version, null: false
        String :section_id, size: 10, null: false
        String :content, text: true, null: false

        index %i[customs_tariff_update_version section_id], unique: true
      end
    end
  end

  down do
    drop_table :customs_tariff_section_notes
  end
end

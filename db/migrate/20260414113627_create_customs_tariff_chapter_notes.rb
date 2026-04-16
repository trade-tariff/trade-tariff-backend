Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      create_table :customs_tariff_chapter_notes do
        primary_key :id
        String :customs_tariff_update_version, null: false
        String :chapter_id, size: 2, null: false
        String :content, text: true, null: false

        index %i[customs_tariff_update_version chapter_id], unique: true
      end
    end
  end

  down do
    drop_table :customs_tariff_chapter_notes
  end
end

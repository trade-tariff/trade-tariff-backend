Sequel.migration do
  up do
    create_table :customs_tariff_section_notes do
      primary_key :id
      String  :customs_tariff_update_version, null: false
      Integer :section_id, null: false
      String  :content, text: true, null: false

      index %i[customs_tariff_update_version section_id], unique: true
    end
  end

  down do
    drop_table :customs_tariff_section_notes
  end
end

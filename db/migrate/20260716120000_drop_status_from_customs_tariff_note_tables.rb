Sequel.migration do
  up do
    %i[customs_tariff_chapter_notes customs_tariff_section_notes customs_tariff_general_rules].each do |table|
      alter_table(table) { drop_column :status }
    end
  end

  down do
    %i[customs_tariff_chapter_notes customs_tariff_section_notes customs_tariff_general_rules].each do |table|
      alter_table(table) { add_column :status, String, null: false, default: 'pending' }
    end
  end
end

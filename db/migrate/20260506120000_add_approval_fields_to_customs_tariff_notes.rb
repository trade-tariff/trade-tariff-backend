Sequel.migration do
  up do
    %i[customs_tariff_section_notes customs_tariff_chapter_notes customs_tariff_general_rules].each do |table|
      alter_table(table) do
        add_column :status, String, null: false, default: 'pending'
        add_column :validity_start_date, Date
        add_column :validity_end_date, Date
      end
    end
  end

  down do
    %i[customs_tariff_section_notes customs_tariff_chapter_notes customs_tariff_general_rules].each do |table|
      alter_table(table) do
        drop_column :status
        drop_column :validity_start_date
        drop_column :validity_end_date
      end
    end
  end
end

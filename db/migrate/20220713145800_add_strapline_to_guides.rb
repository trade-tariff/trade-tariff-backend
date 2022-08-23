Sequel.migration do
  change do
    alter_table :guides do
      add_column :strapline, String, size: 255
      add_column :image, String, size: 255
    end
  end
end

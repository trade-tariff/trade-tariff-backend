Sequel.migration do
  change do
    alter_table :news_items do
      add_column :show_on_banner, 'boolean', null: false, default: false
    end
  end
end

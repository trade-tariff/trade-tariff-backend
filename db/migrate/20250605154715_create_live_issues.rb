# frozen_string_literal: true

Sequel.migration do
  up do
    unless Sequel::Model.db.table_exists?(Sequel[:live_issues].qualify(:public))
      create_table Sequel[:live_issues].qualify(:public) do
        primary_key :id
        String :title, null: false
        String :description, size: 256
        column :commodities, 'text[]', null: false
        String :status, null: false, default: 'Active'
        Date :date_discovered, null: false
        Date :date_resolved
        DateTime :created_at
        DateTime :updated_at
      end
    end
  end

  down do
    if Sequel::Model.db.table_exists?(Sequel[:live_issues].qualify(:public))
      drop_table Sequel[:live_issues].qualify(:public)
    end
  end
end

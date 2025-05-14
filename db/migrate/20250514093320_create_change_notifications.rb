# frozen_string_literal: true

Sequel.migration do
  up do
    unless Sequel::Model.db.table_exists?(Sequel[:change_notifications].qualify(:public))
      create_table Sequel[:change_notifications].qualify(:public), id: :uuid do
        primary_key :id
        foreign_key :user_id, Sequel[:users].qualify(:public), null: false
        String :chapter_ids
        DateTime :updated_at
      end
    end
  end

  down do
    if Sequel::Model.db.table_exists?(Sequel[:change_notifications].qualify(:public))
      alter_table Sequel[:change_notifications].qualify(:public) do
        drop_foreign_key :user_id
      end
    end
   
    drop_table Sequel[:change_notifications].qualify(:public) if Sequel::Model.db.table_exists?(Sequel[:change_notifications].qualify(:public))
  end
end

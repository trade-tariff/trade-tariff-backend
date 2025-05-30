# frozen_string_literal: true

Sequel.migration do
  up do
    unless Sequel::Model.db.table_exists?(Sequel[:user_preferences].qualify(:public))
      create_table Sequel[:user_preferences].qualify(:public), id: :uuid do
        primary_key :id
        foreign_key :user_id, Sequel[:users].qualify(:public), null: false
        String :chapter_ids
        DateTime :updated_at
      end
    end
  end

  down do
    if Sequel::Model.db.table_exists?(Sequel[:user_preferences].qualify(:public))
      alter_table Sequel[:user_preferences].qualify(:public) do
        drop_foreign_key :user_id
      end
    end
   
    drop_table Sequel[:user_preferences].qualify(:public) if Sequel::Model.db.table_exists?(Sequel[:user_preferences].qualify(:public))
  end
end

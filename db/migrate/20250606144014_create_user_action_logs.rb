# frozen_string_literal: true

Sequel.migration do
  up do
    unless Sequel::Model.db.table_exists?(Sequel[:user_action_logs].qualify(:public))
      create_table Sequel[:user_action_logs].qualify(:public) do
        primary_key :id
        foreign_key :user_id, Sequel[:users].qualify(:public), null: false
        String :action
        DateTime :created_at
        DateTime :updated_at
      end
    end
  end

  down do
    if Sequel::Model.db.table_exists?(Sequel[:user_action_logs].qualify(:public))
      alter_table Sequel[:user_action_logs].qualify(:public) do
        drop_foreign_key :user_id
      end
    end

    drop_table Sequel[:user_action_logs].qualify(:public) if Sequel::Model.db.table_exists?(Sequel[:user_action_logs].qualify(:public))
  end
end

# frozen_string_literal: true

Sequel.migration do
  up do
    unless Sequel::Model.db.table_exists?(Sequel[:users].qualify(:public))
      create_table Sequel[:users].qualify(:public), id: :uuid do
        primary_key :id
        String :external_id, null: false
        DateTime :created_at
        DateTime :updated_at
      end
    end

    unless Sequel::Model.db.table_exists?(Sequel[:subscription_types].qualify(:public))
      create_table Sequel[:subscription_types].qualify(:public), id: :uuid do
        primary_key :id
        String :name, null: false
        String :description, null: false
        DateTime :created_at
        DateTime :updated_at
      end
    end

    unless Sequel::Model.db.table_exists?(Sequel[:user_subscriptions].qualify(:public))
      create_table Sequel[:user_subscriptions].qualify(:public), id: :uuid do
        primary_key :id
        foreign_key :user_id, Sequel[:users].qualify(:public), null: false
        foreign_key :subscription_type_id, Sequel[:subscription_types].qualify(:public), null: false
        Boolean :active, null: false, default: true
        Boolean :email, null: false, default: true # the subscription is to be delivered via email
        DateTime :created_at
        DateTime :updated_at
      end
    end
  end

  down do
    if Sequel::Model.db.table_exists?(Sequel[:user_subscriptions].qualify(:public))
      alter_table Sequel[:user_subscriptions].qualify(:public) do
        drop_foreign_key :user_id
        drop_foreign_key :subscription_type_id
      end
    end
   
    drop_table Sequel[:subscription_types].qualify(:public) if Sequel::Model.db.table_exists?(Sequel[:subscription_types].qualify(:public))
    drop_table Sequel[:user_subscriptions].qualify(:public) if Sequel::Model.db.table_exists?(Sequel[:user_subscriptions].qualify(:public))
    drop_table Sequel[:users].qualify(:public) if Sequel::Model.db.table_exists?(Sequel[:users].qualify(:public))
  end
end

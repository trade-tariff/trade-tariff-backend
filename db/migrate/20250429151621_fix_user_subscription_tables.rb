# frozen_string_literal: true

Sequel.migration do
  up do
    run 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'

    if Sequel::Model.db.table_exists?(Sequel[:user_subscriptions].qualify(:public))
      alter_table Sequel[:user_subscriptions].qualify(:public) do
        drop_foreign_key :user_id
        drop_foreign_key :subscription_type_id
      end
    end
   
    drop_table Sequel[:subscription_types].qualify(:public) if Sequel::Model.db.table_exists?(Sequel[:subscription_types].qualify(:public))
    drop_table Sequel[:user_subscriptions].qualify(:public) if Sequel::Model.db.table_exists?(Sequel[:user_subscriptions].qualify(:public))
    drop_table Sequel[:users].qualify(:public) if Sequel::Model.db.table_exists?(Sequel[:users].qualify(:public))

    unless Sequel::Model.db.table_exists?(Sequel[:users].qualify(:public))
      create_table Sequel[:users].qualify(:public) do
        uuid :id, primary_key: true, default: Sequel.function(:gen_random_uuid)
        String :external_id, null: false
        DateTime :created_at
        DateTime :updated_at
      end
    end

    unless Sequel::Model.db.table_exists?(Sequel[:subscription_types].qualify(:public))
      create_table Sequel[:subscription_types].qualify(:public) do
        uuid :id, primary_key: true, default: Sequel.function(:gen_random_uuid)
        String :name, null: false
        String :description, null: false
        DateTime :created_at
        DateTime :updated_at
      end
    end

    unless Sequel::Model.db.table_exists?(Sequel[:user_subscriptions].qualify(:public))
      create_table Sequel[:user_subscriptions].qualify(:public) do
        uuid :id, primary_key: true, default: Sequel.function(:gen_random_uuid)
        String :user_id, null: false
        String :subscription_type_id, null: false
        Boolean :active, null: false, default: true
        Boolean :email, null: false, default: true # the subscription is to be delivered via email
        DateTime :created_at
        DateTime :updated_at
      end
    end
  end

  down do   
    drop_table Sequel[:subscription_types].qualify(:public) if Sequel::Model.db.table_exists?(Sequel[:subscription_types].qualify(:public))
    drop_table Sequel[:user_subscriptions].qualify(:public) if Sequel::Model.db.table_exists?(Sequel[:user_subscriptions].qualify(:public))
    drop_table Sequel[:users].qualify(:public) if Sequel::Model.db.table_exists?(Sequel[:users].qualify(:public))
  end
end

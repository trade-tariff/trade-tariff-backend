# frozen_string_literal: true

Sequel.migration do
  up do
    create_table Sequel[:users].qualify(:public), id: :uuid do
      primary_key :id
      String :external_id, null: false
      DateTime :created_at
      DateTime :updated_at
    end

    create_table Sequel[:subscription_types].qualify(:public), id: :uuid do
      primary_key :id
      String :name, null: false
      String :description, null: false
      DateTime :created_at
      DateTime :updated_at
    end

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

  down do
    alter_table Sequel[:user_subscriptions].qualify(:public) do
      drop_foreign_key :user_id
      drop_foreign_key :subscription_type_id
    end
   
    drop_table Sequel[:subscription_types].qualify(:public) 
    drop_table Sequel[:user_subscriptions].qualify(:public)
    drop_table Sequel[:users].qualify(:public)
  end
end

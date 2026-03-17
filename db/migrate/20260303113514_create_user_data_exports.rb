# frozen_string_literal: true

Sequel.migration do
  up do
    unless Sequel::Model.db.table_exists?(Sequel[:user_data_exports].qualify(:public))
      create_table Sequel[:user_data_exports].qualify(:public) do
        primary_key :id
        foreign_key :user_subscriptions_uuid, Sequel[:user_subscriptions].qualify(:public), type: :uuid, key: :uuid
        String :export_type
        String :s3_key
        String :file_name
        String :status
        DateTime :created_at
        DateTime :updated_at
      end
    end
  end

  down do
    drop_table Sequel[:user_data_exports].qualify(:public) if Sequel::Model.db.table_exists?(Sequel[:user_data_exports].qualify(:public))
  end
end

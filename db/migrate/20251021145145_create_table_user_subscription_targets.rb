# frozen_string_literal: true
Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      unless Sequel::Model.db.table_exists?(Sequel[:user_subscription_targets].qualify(:public))
        create_table Sequel[:user_subscription_targets].qualify(:public), id: :uuid do
          primary_key :id
          foreign_key :user_subscriptions_uuid, Sequel[:user_subscriptions].qualify(:public), type: :uuid, key: :uuid, null: false
          Integer :target_id, null: false
          String :target_type, null: false
          DateTime :updated_at
          DateTime :created_at, null: true
          
          index [:user_subscriptions_uuid, :target_id, :target_type], 
                unique: true, 
                name: :user_subscriptions_target_unique_idx
        end
      end
    end
  end
  down do
    if TradeTariffBackend.uk?
      if Sequel::Model.db.table_exists?(Sequel[:user_subscription_targets].qualify(:public))
        alter_table Sequel[:user_subscription_targets].qualify(:public) do
          drop_foreign_key :user_subscriptions_uuid
        end
        drop_table Sequel[:user_subscription_targets].qualify(:public) if Sequel::Model.db.table_exists?(Sequel[:user_subscription_targets].qualify(:public))
      end
    end
  end
end

# frozen_string_literal: true
Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      if Sequel::Model.db.table_exists?(Sequel[:user_delta_preferences].qualify(:public))
        alter_table Sequel[:user_delta_preferences].qualify(:public) do
          drop_foreign_key :user_id
        end
      end
    
      drop_table Sequel[:user_delta_preferences].qualify(:public) if Sequel::Model.db.table_exists?(Sequel[:user_delta_preferences].qualify(:public))
    end
  end
end

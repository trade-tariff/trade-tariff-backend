# frozen_string_literal: true
Sequel.migration do
  up do
    if TradeTariffBackend.uk?
        alter_table Sequel[:user_subscriptions].qualify(:public) do
          add_column :metadata, :jsonb
        end
    end
  end
end

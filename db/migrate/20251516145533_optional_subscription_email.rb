# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table Sequel[:user_subscriptions].qualify(:public) do
      set_column_allow_null :email
    end
  end
end

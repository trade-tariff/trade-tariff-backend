# frozen_string_literal: true

Sequel.migration do
  change do
    create_table :green_lanes_exempting_additional_code_overrides do
      primary_key :id
      String      :additional_code_type_id, null: false
      String      :additional_code, null: false
      Time        :created_at, null: false
      Time        :updated_at, null: false

      index %i[additional_code_type_id additional_code], unique: true
    end
  end
end

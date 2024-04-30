# frozen_string_literal: true

Sequel.migration do
  change do
    create_table :green_lanes_exempting_certificate_overrides do
      primary_key :id
      String      :certificate_type_code, null: false
      String      :certificate_code, null: false
      Time        :created_at, null: false
      Time        :updated_at, null: false

      index %i[certificate_code certificate_type_code], unique: true
    end
  end
end

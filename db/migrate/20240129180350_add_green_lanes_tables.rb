# frozen_string_literal: true

Sequel.migration do
  change do
    create_table :green_lanes_themes do
      primary_key :id
      Decimal     :section, null: false, unique: true
      String      :theme, size: 255, null: false
      String      :description, null: false
      Integer     :category_implied, null: false
    end

    create_table :green_lanes_category_assessments do
      primary_key :id
      String      :measure_type_id, size: 6, null: false
      String      :regulation_id, size: 255, null: true
      foreign_key :theme_id, :green_lanes_themes, null: false
      index       %i[measure_type_id regulation_id], unique: true
    end
  end
end

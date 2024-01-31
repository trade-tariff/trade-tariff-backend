# frozen_string_literal: true

Sequel.migration do
  change do
    create_table :green_lanes_themes do
      primary_key :id
      Integer     :section, null: false
      Integer     :subsection, null: false
      String      :theme, size: 255, null: false
      String      :description, null: false
      Integer     :category, null: false
      Time        :created_at, null: false
      Time        :updated_at, null: false
      index       %i[section subsection], unique: true
    end

    create_table :green_lanes_category_assessments do
      primary_key :id
      String      :measure_type_id, size: 6, null: false
      String      :regulation_id, size: 255, null: true
      Int         :regulation_role, null: true
      foreign_key :theme_id, :green_lanes_themes, null: false
      Time        :created_at, null: false
      Time        :updated_at, null: false
      index       %i[measure_type_id regulation_id regulation_role], unique: true
      constraint  :regulation_id_requires_role, { regulation_id: nil } => { regulation_role: nil }
    end
  end
end

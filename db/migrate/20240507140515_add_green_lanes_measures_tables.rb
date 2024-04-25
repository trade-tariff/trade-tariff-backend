# frozen_string_literal: true

Sequel.migration do
  change do
    create_table :green_lanes_measures do
      primary_key :id
      foreign_key :category_assessment_id, :green_lanes_category_assessments, null: false
      String      :goods_nomenclature_item_id, size: 10, null: false
      String      :productline_suffix, size: 2, null: false
      Time        :created_at, null: false
      Time        :updated_at, null: false
      index       %i[category_assessment_id goods_nomenclature_item_id productline_suffix], unique: true
    end

    create_table :green_lanes_exemptions do
      primary_key :id
      String      :code, unique: true, null: false
      String      :description, null: false
      Time        :created_at, null: false
      Time        :updated_at, null: false
    end

    create_join_table({ category_assessment_id: :green_lanes_category_assessments,
                        exemption_id: :green_lanes_exemptions },
                      name: :green_lanes_category_assessments_exemptions)
  end
end

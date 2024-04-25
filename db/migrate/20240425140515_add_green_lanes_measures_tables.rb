# frozen_string_literal: true

Sequel.migration do
  change do
    create_table :green_lanes_measures do
      primary_key :id
      foreign_key :category_assessment_id, :green_lanes_category_assessments, null: false
      String      :goods_nomenclature_item_id, size: 10, null: false
      Time        :created_at, null: false
      Time        :updated_at, null: false
      index       %i[category_assessment_id goods_nomenclature_item_id], unique: true
    end

    create_table :green_lanes_exemptions do
      primary_key :id
      String      :code, unique: true
      String      :description, null: false
      Time        :created_at, null: false
      Time        :updated_at, null: false
    end

    create_table :green_lanes_measure_exemptions do
      primary_key :id
      foreign_key :exemption_id, :green_lanes_exemptions, null: false
      foreign_key :green_lanes_measure_id, :green_lanes_measures
      Integer     :measure_sid
      Time        :created_at, null: false
      Time        :updated_at, null: false
      check       :no_measure_if_gl_measure do
        (measure_sid =~ nil) !~ (green_lanes_measure_id =~ nil)
      end
    end
  end
end

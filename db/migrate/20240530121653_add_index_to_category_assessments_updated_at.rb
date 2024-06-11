# frozen_string_literal: true

Sequel.migration do
  change do
    add_index :green_lanes_category_assessments, :updated_at
  end
end

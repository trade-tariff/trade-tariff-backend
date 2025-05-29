module GreenLanes
  class IdentifiedMeasureTypeCategoryAssessment < Sequel::Model(:green_lanes_identified_measure_type_category_assessments)
    set_primary_key :id
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence

    one_to_one :measure_type,
               key: :measure_type_id,
               primary_key: :measure_type_id,
               class: :MeasureType

    many_to_one :theme

    def validate
      super
      validates_unique :measure_type_id
    end
  end
end

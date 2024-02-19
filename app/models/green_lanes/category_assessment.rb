module GreenLanes
  class CategoryAssessment < Sequel::Model(:green_lanes_category_assessments)
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence

    many_to_one :measure_type, class: :MeasureType
    many_to_one :theme

    def validate
      super

      validates_presence :regulation_role if regulation_id.present?
      validates_presence :regulation_id if regulation_role.present?

      validates_unique %i[measure_type_id regulation_id regulation_role], where: (lambda do |ds, obj, _cols|
        if obj.regulation_id.blank?
          ds.where(measure_type_id: obj.measure_type_id)
        else
          ds.where(measure_type_id: obj.measure_type_id, regulation_id: nil, regulation_role: nil)
        end
      end)
    end
  end
end

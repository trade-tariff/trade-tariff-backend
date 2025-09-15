module GreenLanes
  class Exemption < Sequel::Model(:green_lanes_exemptions)
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence
    plugin :association_pks
    plugin :association_dependencies

    many_to_many :category_assessments,
                 join_table: :green_lanes_category_assessments_exemptions,
                 right_key: :category_assessment_id,
                 right_primary_key: :id,
                 left_key: :exemption_id,
                 left_primary_key: :id
    add_association_dependencies category_assessments: :nullify
    plugin :touch, associations: %i[category_assessments]
  end
end

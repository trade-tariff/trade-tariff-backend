module GreenLanes
  class Exemption < Sequel::Model(:green_lanes_exemptions)
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence
    plugin :association_pks

    many_to_many :category_assessments,
                 join_table: :green_lanes_category_assessments_exemptions
  end
end

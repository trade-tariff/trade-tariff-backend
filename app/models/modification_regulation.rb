class ModificationRegulation < Sequel::Model
  plugin :oplog, primary_key: %i[modification_regulation_id
                                 modification_regulation_role], materialized: true
  plugin :time_machine, period_end_column: :effective_end_date

  set_primary_key %i[modification_regulation_id modification_regulation_role]

  one_to_one :base_regulation, key: %i[base_regulation_id base_regulation_role],
                               primary_key: %i[base_regulation_id base_regulation_role]

  one_to_many :green_lanes_category_assessments, class: :'GreenLanes::CategoryAssessment',
                                                 key: %i[regulation_id regulation_role]

  def regulation_id
    modification_regulation_id
  end

  def role
    modification_regulation_role
  end
end

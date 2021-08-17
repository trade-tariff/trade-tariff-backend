class RegulationGroup < Sequel::Model
  plugin :oplog, primary_key: :regulation_group_id

  set_primary_key [:regulation_group_id]

  one_to_many :base_regulations
end

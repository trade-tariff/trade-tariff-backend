class MeasureExcludedGeographicalArea < Sequel::Model
  plugin :oplog, primary_key: %i[measure_sid geographical_area_sid]

  set_primary_key %i[measure_sid geographical_area_sid]

  one_to_one :measure, key: :measure_sid,
                       primary_key: :measure_sid

  one_to_one :geographical_area, key: :geographical_area_sid,
                       primary_key: :geographical_area_sid
end

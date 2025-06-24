class GeographicalAreaDescriptionPeriod < Sequel::Model
  plugin :oplog, primary_key: %i[geographical_area_description_period_sid
                                 geographical_area_sid], materialized: true
  plugin :time_machine

  set_primary_key %i[geographical_area_description_period_sid geographical_area_sid]

  one_to_one :geographical_area_description, key: :geographical_area_description_period_sid,
                                             primary_key: :geographical_area_description_period_sid

end

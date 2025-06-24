class GeographicalAreaDescription < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: %i[geographical_area_description_period_sid
                                 geographical_area_sid], materialized: true

  set_primary_key %i[geographical_area_description_period_sid geographical_area_sid]

  one_to_one :geographical_area, key: :geographical_area_sid,
                                 primary_key: :geographical_area_sid
  one_to_one :geographical_area_description_period, key: :geographical_area_description_period_sid,
                                                    primary_key: :geographical_area_description_period_sid

  dataset_module do
    def latest
      order(Sequel.desc(:operation_date))
    end
  end
end

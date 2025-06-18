class GeographicalAreaMembership < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: %i[geographical_area_sid
                                 geographical_area_group_sid
                                 validity_start_date], materialized: true

  set_primary_key %i[geographical_area_sid
                     geographical_area_group_sid
                     validity_start_date]


  class << self
    def refresh!(concurrently: false)
      db.refresh_view(:geographical_area_memberships, concurrently:)
    end
  end
end

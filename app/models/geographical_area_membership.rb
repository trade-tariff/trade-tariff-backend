class GeographicalAreaMembership < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: %i[geographical_area_sid
                                 geographical_area_group_sid
                                 validity_start_date]

  set_primary_key %i[geographical_area_sid
                     geographical_area_group_sid
                     validity_start_date]

  def self.refresh!
    db.refresh_view(:geographical_area_memberships, concurrently: false)
  end
end

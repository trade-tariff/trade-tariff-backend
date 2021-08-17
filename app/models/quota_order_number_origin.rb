class QuotaOrderNumberOrigin < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: :quota_order_number_origin_sid

  set_primary_key [:quota_order_number_origin_sid]

  one_to_one :geographical_area, key: :geographical_area_sid,
                                 primary_key: :geographical_area_sid,
                                 class_name: GeographicalArea do |ds|
    ds.with_actual(GeographicalArea)
  end
end

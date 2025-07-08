class QuotaOrderNumberOriginExclusion < Sequel::Model
  plugin :oplog, primary_key: %i[quota_order_number_origin_sid
                                 excluded_geographical_area_sid]

  set_primary_key %i[quota_order_number_origin_sid excluded_geographical_area_sid]

  many_to_one :geographical_area, key: :excluded_geographical_area_sid,
                                  primary_key: :geographical_area_sid,
                                  graph_use_association_block: true do |ds|
    ds.with_actual(GeographicalArea)
  end

  delegate :geographical_area_id, to: :geographical_area, allow_nil: true
end

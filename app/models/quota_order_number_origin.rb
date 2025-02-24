class QuotaOrderNumberOrigin < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: :quota_order_number_origin_sid

  set_primary_key [:quota_order_number_origin_sid]

  one_to_one :geographical_area, key: :geographical_area_sid,
                                 primary_key: :geographical_area_sid do |ds|
    ds.with_actual(GeographicalArea)
  end

  delegate :description, to: :geographical_area, prefix: true

  one_to_many :quota_order_number_origin_exclusions,
              key: :quota_order_number_origin_sid

  def quota_order_number_origin_exclusion_ids
    quota_order_number_origin_exclusions.pluck(:id)
  end
end

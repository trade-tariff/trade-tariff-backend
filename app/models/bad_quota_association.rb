class BadQuotaAssociation < Sequel::Model
  plugin :time_machine

  set_primary_key %i[main_quota_order_number_id sub_quota_order_number_id validity_start_date validity_end_date]

  set_dataset dataset.where(linkage: 'self')
end

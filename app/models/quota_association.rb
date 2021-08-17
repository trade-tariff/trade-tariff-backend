class QuotaAssociation < Sequel::Model
  plugin :oplog, primary_key: %i[main_quota_definition_sid
                                 sub_quota_definition_sid]

  set_primary_key %i[main_quota_definition_sid sub_quota_definition_sid]
end

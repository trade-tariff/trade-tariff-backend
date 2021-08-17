class QuotaUnblockingEvent < Sequel::Model
  plugin :oplog, primary_key: %i[oid quota_definition_sid]

  set_primary_key [:quota_definition_sid]

  def self.status
    'Unblocked'
  end
end

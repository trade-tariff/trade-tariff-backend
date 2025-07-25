class QuotaUnblockingEvent < Sequel::Model
  plugin :oplog, primary_key: %i[quota_definition_sid occurrence_timestamp], materialized: true

  set_primary_key %i[quota_definition_sid occurrence_timestamp]

  many_to_one :quota_definition, key: :quota_definition_sid, primary_key: :quota_definition_sid

  def self.status
    'Open'
  end

  def event_type
    'Unblocking event'
  end
end

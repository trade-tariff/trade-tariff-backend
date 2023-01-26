class QuotaUnsuspensionEvent < Sequel::Model
  plugin :oplog, primary_key: :quota_definition_sid

  set_primary_key [:quota_definition_sid]

  many_to_one :quota_definition, key: :quota_definition_sid,
                                 primary_key: :quota_definition_sid

  def self.status
    'Open'
  end

  def event_type
    'Unsuspension event'
  end
end

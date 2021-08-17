class QuotaCriticalEvent < Sequel::Model
  plugin :oplog, primary_key: %i[quota_definition_sid occurrence_timestamp]

  set_primary_key %i[quota_definition_sid occurrence_timestamp]

  many_to_one :quota_definition, key: :quota_definition_sid,
                                 primary_key: :quota_definition_sid

  def self.status
    'Critical'
  end
end

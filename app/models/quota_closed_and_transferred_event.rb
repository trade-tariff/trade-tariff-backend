class QuotaClosedAndTransferredEvent < Sequel::Model
  plugin :oplog, primary_key: %i[quota_definition_sid
                                 occurrence_timestamp]

  set_primary_key %i[quota_definition_sid occurrence_timestamp]

  many_to_one :quota_definition, key: :quota_definition_sid,
                                 primary_key: :quota_definition_sid

  many_to_one :target_quota_definition, class_name: 'QuotaDefinition', key: :target_quota_definition_sid,
                                        primary_key: :quota_definition_sid
  def id
    "#{quota_definition_sid}-#{occurrence_timestamp.iso8601}"
  end

  def self.status; end
end

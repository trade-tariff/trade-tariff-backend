class QuotaCriticalEvent < Sequel::Model
  ACTIVE_CRITICAL_STATE = 'Y'.freeze
  INACTIVE_CRITICAL_STATE = 'N'.freeze

  plugin :oplog, primary_key: %i[quota_definition_sid occurrence_timestamp], materialized: true

  set_primary_key %i[quota_definition_sid occurrence_timestamp]

  many_to_one :quota_definition, key: :quota_definition_sid,
                                 primary_key: :quota_definition_sid

  def active?
    critical_state == QuotaCriticalEvent::ACTIVE_CRITICAL_STATE
  end

  def self.status
    'Critical'
  end

  def event_type
    'Critical state change'
  end
end

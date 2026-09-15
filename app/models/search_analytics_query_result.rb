# frozen_string_literal: true

class SearchAnalyticsQueryResult < Sequel::Model
  def self.fetch(service:, reporting_date:, name:, fingerprint:, force: false)
    identity = { service:, reporting_date:, name: }
    lock_id = Digest::SHA256.digest([table_name, service, reporting_date.iso8601, name].to_json).unpack1('q>')
    db.with_advisory_lock(lock_id, wait: true) do
      cached = where(identity.merge(fingerprint:)).first unless force
      return cached.rows.to_a if cached

      rows = yield
      raise ArgumentError, 'Query results must be an array' unless rows.is_a?(Array)

      attributes = identity.merge(fingerprint:, rows: Sequel.pg_jsonb(rows), collected_at: Time.current)
      dataset.insert_conflict(target: identity.keys, update: attributes).insert(attributes)
      rows
    end
  end
end

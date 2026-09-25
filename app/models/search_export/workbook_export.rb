# frozen_string_literal: true

module SearchExport
  # Temporary job handoff, not a cache. Status polls never read workbook bytes.
  class WorkbookExport
    RETENTION = 1.hour
    QUEUED = 'queued'
    RUNNING = 'running'
    READY = 'ready'
    FAILED = 'failed'

    attr_reader :id

    def self.create(from_date:, to_date:)
      export = new(SecureRandom.uuid)
      now = Time.current
      payload = { status: QUEUED, from: from_date.iso8601, to: to_date.iso8601, updated_at: now.iso8601 }
      Sidekiq.redis { |redis| redis.set(export.key, payload.to_json, ex: RETENTION.to_i) }

      export
    end

    def self.find(id)
      return unless id.to_s.match?(/\A[0-9a-f-]{36}\z/)

      export = new(id)
      export if export.payload
    end

    def initialize(id)
      @id = id
    end

    def key = "search_export:#{TradeTariffBackend.service}:#{id}"
    def file_key = "#{key}:file"

    def payload
      value = Sidekiq.redis { |redis| redis.get(key) }
      JSON.parse(value) if value
    end

    def file
      Sidekiq.redis { |redis| redis.get(file_key) }
    end

    def delete
      Sidekiq.redis { |redis| redis.del(key, file_key) }
    end

    def claim
      transition(from: QUEUED, status: RUNNING)
    end

    def finish(result)
      transition(from: RUNNING, status: READY, file: result.bytes, row_count: result.row_count, omitted_count: result.omitted_count)
    end

    def fail(message)
      transition(from: RUNNING, status: FAILED, error: message)
    end

  private

    def transition(from:, file: nil, **attributes)
      Sidekiq.redis do |redis|
        # Abort if another worker changes the status or its key expires.
        changed = redis.multi(watch: [key]) do |transaction|
          stored = redis.get(key)&.then { |value| JSON.parse(value) }
          ttl = redis.pttl(key)
          next unless stored && stored['status'] == from && ttl.positive?

          updated = stored.merge(attributes.stringify_keys).merge('updated_at' => Time.current.iso8601)
          transaction.set(file_key, file, px: ttl) if file
          transaction.set(key, updated.to_json, keepttl: true)
        end
        changed.present?
      end
    end
  end
end

# frozen_string_literal: true

module SearchExport
  # Temporary job handoff, not a cache. Status polls never read workbook bytes.
  class WorkbookExport
    Busy = Class.new(StandardError)
    TooLarge = Class.new(StandardError)
    RETENTION = 1.hour
    DEADLINE = 15.minutes
    MAX_EXPORTS = 3
    MAX_FILE_BYTES = 10.megabytes
    QUEUED = 'queued'
    RUNNING = 'running'
    READY = 'ready'
    FAILED = 'failed'

    CREATE = <<~LUA
      redis.call('ZREMRANGEBYSCORE', KEYS[1], '-inf', ARGV[1])
      if redis.call('ZCARD', KEYS[1]) >= tonumber(ARGV[2]) then return 0 end
      redis.call('SET', KEYS[2], ARGV[3], 'EX', ARGV[4])
      redis.call('ZADD', KEYS[1], ARGV[5], KEYS[2])
      redis.call('EXPIRE', KEYS[1], ARGV[4])
      return 1
    LUA
    TRANSITION = <<~LUA
      if redis.call('GET', KEYS[1]) ~= ARGV[1] then return 0 end
      local ttl = redis.call('PTTL', KEYS[1])
      if ttl <= 0 then return 0 end
      if ARGV[3] == 'file' then redis.call('SET', KEYS[2], ARGV[4], 'PX', ttl) end
      redis.call('SET', KEYS[1], ARGV[2], 'KEEPTTL')
      return 1
    LUA

    attr_reader :id

    def self.create(from_date:, to_date:, **)
      export = new(SecureRandom.uuid)
      now = Time.current
      payload = { status: QUEUED, from: from_date.iso8601, to: to_date.iso8601, updated_at: now.iso8601 }
      created = Sidekiq.redis do |redis|
        redis.call('EVAL', CREATE, 2, export.registry_key, export.key, now.to_f, MAX_EXPORTS, payload.to_json, RETENTION.to_i, (now + RETENTION).to_f)
      end
      raise Busy, 'Three exports are already retained. Please try again after they expire.' unless created == 1

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

    def registry_key = "search_export:#{TradeTariffBackend.service}:exports"
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
      Sidekiq.redis do |redis|
        redis.multi do |transaction|
          transaction.del(key, file_key)
          transaction.zrem(registry_key, key)
        end
      end
    end

    def claim
      expire_if_stale!
      transition(from: QUEUED, status: RUNNING)
    end

    def finish(result)
      raise TooLarge, 'Workbook exceeds 10 MiB. Please shorten the date range.' if result.bytes.bytesize > MAX_FILE_BYTES

      expire_if_stale!
      transition(from: RUNNING, status: READY, file: result.bytes, row_count: result.row_count, omitted_count: result.omitted_count)
    end

    def fail(message)
      transition(from: RUNNING, status: FAILED, error: message)
    end

    def expire_if_stale!
      stored = payload
      return unless stored && [QUEUED, RUNNING].include?(stored['status']) && Time.iso8601(stored.fetch('updated_at')) < DEADLINE.ago

      transition(from: stored['status'], status: FAILED, error: 'The workbook timed out. Please request it again.')
    end

  private

    def transition(from:, file: nil, **attributes)
      Sidekiq.redis do |redis|
        previous = redis.get(key)
        next false unless previous

        stored = JSON.parse(previous)
        next false unless stored['status'] == from

        updated = stored.merge(attributes.stringify_keys).merge('updated_at' => Time.current.iso8601)
        redis.call('EVAL', TRANSITION, 2, key, file_key, previous, updated.to_json, file ? 'file' : '', file || '') == 1
      end
    end
  end
end

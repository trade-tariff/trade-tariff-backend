class QueuedSearch
  RETENTION = 1.hour

  # Compare the full previous payload so duplicate workers cannot claim the same
  # search or overwrite a terminal result. KEEPTTL prevents extending retention.
  TRANSITION = <<~LUA.freeze
    if redis.call('GET', KEYS[1]) == ARGV[1] then
      redis.call('SET', KEYS[1], ARGV[2], 'KEEPTTL')
      return 1
    end
    return 0
  LUA

  attr_reader :id

  def self.create(params:, context:)
    search = new(SecureRandom.uuid)
    now = Time.current.iso8601
    payload = { id: search.id, status: 'queued', params:, context:, created_at: now, updated_at: now }
    Sidekiq.redis { |redis| redis.set(search.key, payload.to_json, ex: RETENTION.to_i) }
    search
  end

  def initialize(id)
    @id = id
  end

  def key
    "queued_search:#{TradeTariffBackend.service}:#{id}"
  end

  def payload
    stored = Sidekiq.redis { |redis| redis.get(key) }
    JSON.parse(stored) if stored
  end

  def delete
    Sidekiq.redis { |redis| redis.del(key) }
  end

  def claim
    transition(from: 'queued', status: 'running')
  end

  def finish(result:, response_status:)
    status = response_status == 200 ? 'completed' : 'failed'
    transition(from: 'running', status:, result:, response_status:)
  end

private

  def transition(from:, **attributes)
    Sidekiq.redis do |redis|
      previous = redis.get(key)
      next unless previous

      payload = JSON.parse(previous)
      next unless payload['status'] == from

      updated = payload.merge(attributes.stringify_keys).merge('updated_at' => Time.current.iso8601)
      changed = redis.call('EVAL', TRANSITION, 1, key, previous, updated.to_json)
      updated if changed == 1
    end
  end
end

module Search
  # Opt-in reuse of successful search model output across tariff cache clears.
  # Entries live in the backend cache Redis under their own namespace, so a
  # namespaced Rails.cache.clear leaves them in place. They still expire, and
  # Redis can evict them early under memory pressure. Values are plain JSON.
  class InferenceCache
    TTL = 7.days
    MAX_PAYLOAD_BYTES = 64.kilobytes
    TIMEOUT_SECONDS = 0.5

    class << self
      def enabled?
        TradeTariffBackend.search_inference_cache_enabled?
      end

      def key(operation:, inputs:)
        "#{operation}/#{Digest::SHA256.hexdigest(inputs.to_json)}"
      end

      # Returns the cached Hash, or nil. An optional block validates the value;
      # a rejected value is deleted and treated as a miss.
      def read(key, operation:, request_id:)
        return unless enabled?

        payload = store.read(key, raw: true)
        return report(operation:, request_id:, outcome: 'miss') if payload.nil?

        value = parse(payload)
        if value && (!block_given? || yield(value))
          report(operation:, request_id:, outcome: 'hit', payload_bytes: payload.bytesize)
          return value
        end

        delete(key, operation:, request_id:)
      rescue StandardError => e
        report(operation:, request_id:, outcome: 'error', error_type: e.class.name)
      end

      def write(key, value, operation:, request_id:)
        return unless enabled?

        payload = value.to_json
        if payload.bytesize > MAX_PAYLOAD_BYTES
          return report(operation:, request_id:, outcome: 'too_large', payload_bytes: payload.bytesize)
        end

        store.write(key, payload, raw: true, expires_in: TTL)
        report(operation:, request_id:, outcome: 'write', payload_bytes: payload.bytesize)
      rescue StandardError => e
        report(operation:, request_id:, outcome: 'error', error_type: e.class.name)
      end

      def delete(key, operation:, request_id:)
        return unless enabled?

        store.delete(key)
        report(operation:, request_id:, outcome: 'rejected')
      rescue StandardError => e
        report(operation:, request_id:, outcome: 'error', error_type: e.class.name)
      end

      def clear(operation:)
        return unless enabled?

        store.delete_matched("#{operation}/*")
      rescue StandardError => e
        report(operation:, request_id: nil, outcome: 'error', error_type: e.class.name)
      end

      def namespace
        "search-inference-#{Rails.env}-#{TradeTariffBackend.service}-v1"
      end

      def store
        @store ||= ActiveSupport::Cache::RedisCacheStore.new(
          **TradeTariffBackend.redis_config,
          namespace: -> { namespace },
          expires_in: TTL,
          connect_timeout: TIMEOUT_SECONDS,
          read_timeout: TIMEOUT_SECONDS,
          write_timeout: TIMEOUT_SECONDS,
          pool: { size: TradeTariffBackend.max_threads },
          # Raise so the caller reports the error against its search operation.
          error_handler: ->(exception:, **) { raise exception },
        )
      end

    private

      def parse(payload)
        return unless payload.is_a?(String) && payload.bytesize <= MAX_PAYLOAD_BYTES

        value = JSON.parse(payload)
        value if value.is_a?(Hash)
      rescue JSON::ParserError
        nil
      end

      def report(**payload)
        Search::Instrumentation.inference_cache_access(**payload)
        nil
      end
    end
  end
end

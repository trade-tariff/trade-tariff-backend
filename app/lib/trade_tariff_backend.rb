require 'opensearch/version'

module TradeTariffBackend
  MAX_LOCK_LIFETIME = 600_000
  REVISION_FILE = 'REVISION'.freeze
  SERVICE_CURRENCIES = {
    'uk' => 'GBP',
    'xi' => 'EUR',
  }.freeze
end

require_relative 'trade_tariff_backend/config'
require_relative 'trade_tariff_backend/clients'
require_relative 'trade_tariff_backend/tariff_update_event_listener'
require_relative 'trade_tariff_backend/search_response'
require_relative 'trade_tariff_backend/service_timeout'

module TradeTariffBackend
  extend Config
  extend Clients

  class << self
    def configure
      yield self
    end

    def with_redis_lock(lock_name = 'tariff-lock', &block)
      lock = Redlock::Client.new([RedisLockDb.redis])
      lock.lock!(lock_name, MAX_LOCK_LIFETIME, &block)
    end

    def reindex(indexer = search_client)
      TimeMachine.with_relevant_validity_periods do
        indexer.update_all
      rescue StandardError => e
        Mailer.reindex_exception(e).deliver_now
      end
    end

    # Number of changes to fetch for Commodity/Heading/Chapter
    def change_count
      10
    end

    def api_version(request)
      request.headers['Accept']&.scan(/application\/vnd.uktt.v(\d+)/)&.flatten&.first || '1'
    end

    def error_serializer(request)
      "Api::V#{api_version(request)}::ErrorSerializationService".constantize.new
    end

    def rules_of_origin
      @rules_of_origin ||= RulesOfOrigin::DataSet.load_default
    end

    def stop_words
      @stop_words ||= Set.new(YAML.load_file(stop_words_file)[:stop_words])
    end

    def stop_words_file
      Rails.root.join('db/stop_words.yml')
    end

    def revision
      @revision ||= begin
        File.read(REVISION_FILE).chomp if File.file?(REVISION_FILE)
      rescue Errno::EACCES
        nil
      end
    end

    def user_agent
      "TradeTariffBackend/#{revision}"
    end

    def data_migration_path
      Rails.root.join('db/data_migrations')
    end

    def tariff_sync_retry_count
      ENV.fetch('TARIFF_SYNC_RETRY_COUNT', 20).to_i
    end

    def exception_retry_count
      ENV.fetch('EXCEPTION_RETRY_COUNT', 10).to_i
    end

    def request_throttle
      ENV.fetch('REQUEST_THROTTLE', 60).to_i
    end

    def cut_off_time
      ENV.fetch('CUT_OFF_TIME', '10:00')
    end

    def try_again_in
      ENV.fetch('TRY_AGAIN_IN', 20).minutes
    end

    def empty_file_size_threshold
      ENV.fetch('EMPTY_FILE_SIZE_THRESHOLD', 500).to_i
    end
  end
end

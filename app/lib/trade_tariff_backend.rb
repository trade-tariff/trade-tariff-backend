require 'opensearch/version'

module TradeTariffBackend
  MAX_LOCK_LIFETIME = 600_000
  REVISION_FILE = Rails.root.join('REVISION').to_s.freeze

  class << self
    SERVICE_CURRENCIES = {
      'uk' => 'GBP',
      'xi' => 'EUR',
    }.freeze

    def configure
      yield self
    end

    # URL used to specify the location of the search query parser application
    def search_query_parser_url
      ENV['TARIFF_QUERY_SEARCH_PARSER_URL']
    end

    # Lock key used for DB locks to keep just one instance of synchronizer
    # running in cluster environment
    def db_lock_key
      'tariff-lock'
    end

    def log_formatter
      proc { |severity, time, _progname, msg| "#{time.strftime('%Y-%m-%dT%H:%M:%S.%L %z')} #{sprintf('%5s', severity)} #{msg}\n" }
    end

    # Email of the user who receives all info/error notifications
    def from_email
      ENV.fetch('TARIFF_FROM_EMAIL')
    end

    # Email of the user who receives all info/error notifications
    def admin_email
      ENV.fetch('TARIFF_SYNC_EMAIL')
    end

    def use_cds?
      ENV['CDS'] == 'true'
    end

    def patch_broken_taric_downloads?
      ENV['PATCH_BROKEN_TARIC_DOWNLOADS'] == 'true'
    end

    def dump_cds_data_as_json?
      ENV.fetch('DUMP_CDS_DATA_AS_JSON', 'false') == 'true'
    end

    def uk?
      service == 'uk'
    end

    def xi?
      service == 'xi'
    end

    def service
      ENV.fetch('SERVICE', 'uk')
    end

    def deployed_environment
      ENV.fetch('ENVIRONMENT', Rails.env)
    end

    def currency
      SERVICE_CURRENCIES.fetch(service, 'GBP')
    end

    def data_migration_path
      Rails.root.join('db/data_migrations')
    end

    def with_redis_lock(lock_name = db_lock_key, &block)
      lock = Redlock::Client.new([RedisLockDb.redis])
      lock.lock!(lock_name, MAX_LOCK_LIFETIME, &block)
    end

    def redis_config
      db = Rails.env.test? ? 1 : 0

      { url: ENV['REDIS_URL'], db:, id: nil }
    end

    def redis
      @redis ||= Redis.new(redis_config)
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

    def number_formatter
      @number_formatter ||= TradeTariffBackend::NumberFormatter.new
    end

    def search_client
      @search_client ||= SearchClient.new(
        opensearch_client,
        indexes: search_indexes,
      )
    end

    def search_indexes
      [
        Search::ChapterIndex,
        Search::CommodityIndex,
        Search::HeadingIndex,
        Search::SearchReferenceIndex,
        Search::SectionIndex,
      ].map(&:new)
    end

    def check_query_count?
      excess_query_threshold.positive?
    end

    def excess_query_threshold
      @excess_query_threshold ||= ENV['EXCESS_QUERY_THRESHOLD'].presence.to_i
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

    def synonym_reference_analyzer
      ENV['SYNONYM_REFERENCE_ANALYZER']
    end

    def stemming_exclusion_reference_analyzer
      ENV['STEMMING_EXCLUSION_REFERENCE_ANALYZER']
    end

    def handle_missing_soft_deletes?
      ENV['SOFT_DELETES_MISSING'].to_s == 'true'
    end

    def frontend_host
      ENV['FRONTEND_HOST']
    end

    def reporting_cdn_host
      ENV['REPORTING_CDN_HOST']
    end

    def opensearch_client
      @opensearch_client ||= OpenSearch::Client.new(opensearch_configuration)
    end

    def opensearch_configuration
      {
        host: opensearch_host,
        log: opensearch_debug,
      }
    end

    def bulk_search_api_enabled?
      ENV.fetch('BULK_SEARCH_API_ENABLED', 'false') == 'true'
    end

    def opensearch_host
      ENV.fetch('ELASTICSEARCH_URL', 'http://host.docker.internal:9200')
    end

    def xe_api_url
      ENV['XE_API_URL']
    end

    def xe_api_username
      ENV['XE_API_USERNAME']
    end

    def xe_api_password
      ENV['XE_API_PASSWORD']
    end

    def differences_report_to_emails
      ENV['DIFFERENCES_TO_EMAILS']
    end

    def support_email
      ENV['TARIFF_SUPPORT_EMAIL']
    end

    def management_email
      ENV['TARIFF_MANAGEMENT_EMAIL']
    end

    def opensearch_debug
      ENV.fetch('OPENSEARCH_DEBUG', 'false') == 'true'
    end

    def green_lanes_api_tokens
      ENV['GREEN_LANES_API_TOKENS']
    end

    def green_lanes_api_keys
      ENV['GREEN_LANES_API_KEYS']
    end

    def excise_alcohol_coercian_starts_from
      @excise_alcohol_coercian_starts_from ||= Date.parse(
        ENV.fetch(
          'ALCOHOL_COERCIAN_STARTS_FROM',
          '2023-08-01',
        ),
      )
    end

    def revision
      @revision ||= begin
        File.read(REVISION_FILE).chomp if File.file?(REVISION_FILE)
      rescue Errno::EACCES
        nil
      end
    end

    def frontend_redis
      @frontend_redis ||= begin
        url = ENV.fetch('FRONTEND_REDIS_URL', 'redis://host.docker.internal:6379')
        db = Rails.env.test? ? 1 : 0

        Redis.new(url:, db:)
      end
    end

    def legacy_search_enhancements_enabled?
      ENV.fetch('LEGACY_SEARCH_ENHANCEMENTS_ENABLED', 'false') == 'true'
    end

    def enable_admin?
      ENV['ENABLE_ADMIN'].to_s == 'true'
    end

    def green_lanes_update_email
      ENV['GREEN_LANES_UPDATE_EMAIL']
    end

    def green_lanes_notify_measure_updates
      ENV['GREEN_LANES_NOTIFY_MEASURE_UPDATES'].to_s == 'true'
    end

    def disable_admin_api_authentication?
      ENV.fetch('DISABLE_ADMIN_API_AUTHENTICATION', 'false').to_s == 'true'
    end
  end
end

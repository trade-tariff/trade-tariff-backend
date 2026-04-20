module TradeTariffBackend
  module Config
    # Tariff sync credentials and behaviour
    def tariff_sync_username
      ENV['TARIFF_SYNC_USERNAME']
    end

    def tariff_sync_password
      ENV['TARIFF_SYNC_PASSWORD']
    end

    def tariff_sync_host
      ENV['TARIFF_SYNC_HOST']
    end

    def tariff_ignore_presence_errors
      ENV.fetch('TARIFF_IGNORE_PRESENCE_ERRORS', '1') == '1'
    end

    def patch_broken_taric_downloads?
      ENV['PATCH_BROKEN_TARIC_DOWNLOADS'] == 'true'
    end

    def dump_cds_data_as_json?
      ENV.fetch('DUMP_CDS_DATA_AS_JSON', 'false') == 'true'
    end

    def cds_importer_batch_size
      ENV.fetch('CDS_IMPORT_BATCH_SIZE', '100').to_i
    end

    def implicit_deletion_cutoff
      Date.parse(ENV.fetch('IMPLICIT_DELETION_CUTOFF', '2024-03-25'))
    end

    # Infrastructure
    def max_threads
      ENV.fetch('MAX_THREADS', '6').to_i
    end

    def aws_region
      ENV.fetch('AWS_REGION', 'eu-west-2')
    end

    def allow_missing_migration_files
      ENV.fetch('ALLOW_MISSING_MIGRATION_FILES', 'true') == 'true'
    end

    def excess_query_threshold
      @excess_query_threshold ||= ENV['EXCESS_QUERY_THRESHOLD'].presence.to_i
    end

    def check_query_count?
      excess_query_threshold.positive?
    end

    # Service / request context
    def service
      ENV.fetch('SERVICE', 'uk')
    end

    def uk?
      service == 'uk'
    end

    def xi?
      service == 'xi'
    end

    def environment
      ActiveSupport::StringInquirer.new(ENV.fetch('ENVIRONMENT', 'local'))
    end

    def deployed_environment
      ENV.fetch('ENVIRONMENT', Rails.env)
    end

    def currency
      SERVICE_CURRENCIES.fetch(service, 'GBP')
    end

    # Redis connection config (no connections created here)
    def redis_config
      db = Rails.env.test? ? 1 : 0
      { url: ENV['REDIS_URL'], db:, id: nil }
    end

    def sidekiq_redis_config
      db = Rails.env.test? ? 1 : 0
      { url: ENV.fetch('SIDEKIQ_REDIS_URL', ENV['REDIS_URL']), db:, id: nil, timeout: 5 }
    end

    def frontend_redis_url
      ENV.fetch('FRONTEND_REDIS_URL', 'redis://host.docker.internal:6379')
    end

    # OpenSearch
    def opensearch_host
      ENV.fetch('ELASTICSEARCH_URL', 'http://host.docker.internal:9200')
    end

    def opensearch_debug
      ENV.fetch('OPENSEARCH_DEBUG', 'false') == 'true'
    end

    def opensearch_configuration
      { host: opensearch_host, log: opensearch_debug }
    end

    # Slack notifications
    def slack_web_hook_url
      ENV['SLACK_WEB_HOOK_URL']
    end

    def slack_channel
      ENV.fetch('SLACK_CHANNEL', '#tariffs-etl')
    end

    def slack_username
      ENV.fetch('SLACK_USERNAME', 'Trade Tariff Backend')
    end

    def slack_failures_enabled?
      ENV.fetch('SLACK_FAILURES_ENABLED', 'false').to_s == 'true'
    end

    def slack_failures_channel
      ENV.fetch('SLACK_FAILURES_CHANNEL', '#production-alerts')
    end

    # Auth / identity
    def cognito_user_pool_id
      ENV['COGNITO_USER_POOL_ID']
    end

    def identity_encryption_secret
      ENV['IDENTITY_ENCRYPTION_SECRET']
    end

    def identity_api_host
      ENV['IDENTITY_API_HOST']
    end

    def identity_api_key
      ENV['IDENTITY_API_KEY']
    end

    # Email addresses
    def from_email
      ENV.fetch('TARIFF_FROM_EMAIL')
    end

    def admin_email
      ENV.fetch('TARIFF_SYNC_EMAIL')
    end

    def support_email
      ENV['TARIFF_SUPPORT_EMAIL']
    end

    def management_email
      ENV['TARIFF_MANAGEMENT_EMAIL']
    end

    def differences_report_to_emails
      ENV['DIFFERENCES_TO_EMAILS']
    end

    def cds_updates_send_email
      ENV.fetch('CDS_UPDATES_SEND_MAIL', 'false').to_s == 'true'
    end

    def cds_updates_to_email
      ENV.fetch('CDS_UPDATES_TO_EMAILS')
    end

    def cds_updates_cc_email
      ENV.fetch('CDS_UPDATES_CC_EMAILS', '')
    end

    def cupid_team_to_emails
      ENV['CUPID_TEAM_TO_EMAILS']
    end

    def myott_report_email
      ENV['MYOTT_REPORT_EMAIL']
    end

    # Frontend / reporting URLs
    def frontend_host
      ENV['FRONTEND_HOST']
    end

    def reporting_cdn_host
      return ENV['REPORTING_CDN_HOST'] if ENV['REPORTING_CDN_HOST'].present?

      {
        'production' => 'https://reporting.trade-tariff.service.gov.uk',
        'staging' => 'https://reporting.staging.trade-tariff.service.gov.uk',
        'development' => 'https://reporting.dev.trade-tariff.service.gov.uk',
      }[environment.to_s]
    end

    # XE currency exchange API
    def xe_api_url
      ENV.fetch('XE_API_URL', 'https://xecdapi.xe.com')
    end

    def xe_api_username
      ENV['XE_API_USERNAME']
    end

    def xe_api_password
      ENV['XE_API_PASSWORD']
    end

    # Alcohol coercion
    def alcohol_coercian_starts_from
      ENV.fetch('ALCOHOL_COERCIAN_STARTS_FROM', '2022-01-01')
    end

    def excise_alcohol_coercian_starts_from
      @excise_alcohol_coercian_starts_from ||= Date.parse(alcohol_coercian_starts_from)
    end

    # Green Lanes
    def api_tokens
      ENV['GREEN_LANES_API_TOKENS']
    end

    def green_lanes_api_keys
      ENV.fetch('GREEN_LANES_API_KEYS', '{}')
    end

    def green_lanes_update_email
      ENV['GREEN_LANES_UPDATE_EMAIL']
    end

    def green_lanes_notify_measure_updates
      ENV.fetch('GREEN_LANES_NOTIFY_MEASURE_UPDATES', 'false') == 'true'
    end

    # AI / OpenAI
    def ai_model
      ENV.fetch('AI_MODEL', 'gpt-5.2')
    end

    def openai_user
      ENV.fetch('OPENAI_USER', 'hmrc-ott')
    end

    def openai_api_key
      ENV['OPENAI_API_KEY']
    end

    def openai_api_base_url
      ENV.fetch('OPENAI_API_BASE_URL', 'https://api.openai.com/v1')
    end

    def openai_api_timeout
      ENV.fetch('OPENAI_API_TIMEOUT', '180').to_i
    end

    def openai_api_open_timeout
      ENV.fetch('OPENAI_API_OPEN_TIMEOUT', '60').to_i
    end

    # Goods nomenclature
    def goods_nomenclature_label_page_size
      ENV.fetch('GOODS_NOMENCLATURE_LABEL_PAGE_SIZE', '10').to_i
    end
  end
end

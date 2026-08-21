RSpec.describe TradeTariffBackend::Config do
  subject(:config) { TradeTariffBackend }

  # Helpers to temporarily override ENV vars
  around do |example|
    original = ENV.to_h
    example.run
  ensure
    ENV.replace(original)
  end

  describe 'tariff sync config' do
    it 'reads TARIFF_SYNC_USERNAME from ENV' do
      ENV['TARIFF_SYNC_USERNAME'] = 'user'
      expect(config.tariff_sync_username).to eq('user')
    end

    it 'reads TARIFF_SYNC_PASSWORD from ENV' do
      ENV['TARIFF_SYNC_PASSWORD'] = 'secret'
      expect(config.tariff_sync_password).to eq('secret')
    end

    it 'reads TARIFF_SYNC_HOST from ENV' do
      ENV['TARIFF_SYNC_HOST'] = 'https://sync.example.com'
      expect(config.tariff_sync_host).to eq('https://sync.example.com')
    end

    describe '.tariff_ignore_presence_errors' do
      it 'defaults to true' do
        ENV.delete('TARIFF_IGNORE_PRESENCE_ERRORS')
        expect(config.tariff_ignore_presence_errors).to be true
      end

      it 'returns false when set to 0' do
        ENV['TARIFF_IGNORE_PRESENCE_ERRORS'] = '0'
        expect(config.tariff_ignore_presence_errors).to be false
      end
    end

    describe '.patch_broken_taric_downloads?' do
      it 'defaults to false' do
        ENV.delete('PATCH_BROKEN_TARIC_DOWNLOADS')
        expect(config.patch_broken_taric_downloads?).to be false
      end

      it 'returns true when set' do
        ENV['PATCH_BROKEN_TARIC_DOWNLOADS'] = 'true'
        expect(config.patch_broken_taric_downloads?).to be true
      end
    end

    describe '.dump_cds_data_as_json?' do
      it 'defaults to false' do
        ENV.delete('DUMP_CDS_DATA_AS_JSON')
        expect(config.dump_cds_data_as_json?).to be false
      end

      it 'returns true when set' do
        ENV['DUMP_CDS_DATA_AS_JSON'] = 'true'
        expect(config.dump_cds_data_as_json?).to be true
      end
    end

    shared_examples 'a configurable batch size' do
      it 'defaults to 100' do
        ENV.delete(env_var)
        expect(config.public_send(method_name)).to eq(100)
      end

      it 'returns configured value as integer' do
        ENV[env_var] = '250'
        expect(config.public_send(method_name)).to eq(250)
      end

      it 'falls back to 100 when configured value is zero' do
        ENV[env_var] = '0'
        expect(config.public_send(method_name)).to eq(100)
      end

      it 'falls back to 100 when configured value is negative' do
        ENV[env_var] = '-5'
        expect(config.public_send(method_name)).to eq(100)
      end

      it 'falls back to 100 when configured value is not numeric' do
        ENV[env_var] = 'abc'
        expect(config.public_send(method_name)).to eq(100)
      end
    end

    describe '.cds_importer_batch_size' do
      let(:env_var) { 'CDS_IMPORT_BATCH_SIZE' }
      let(:method_name) { :cds_importer_batch_size }

      it_behaves_like 'a configurable batch size'
    end

    describe '.taric_importer_batch_size' do
      let(:env_var) { 'TARIC_IMPORT_BATCH_SIZE' }
      let(:method_name) { :taric_importer_batch_size }

      it_behaves_like 'a configurable batch size'
    end

    describe '.implicit_deletion_cutoff' do
      it 'defaults to 2024-03-25' do
        ENV.delete('IMPLICIT_DELETION_CUTOFF')
        expect(config.implicit_deletion_cutoff).to eq(Date.new(2024, 3, 25))
      end

      it 'parses the configured date' do
        ENV['IMPLICIT_DELETION_CUTOFF'] = '2025-06-01'
        expect(config.implicit_deletion_cutoff).to eq(Date.new(2025, 6, 1))
      end
    end
  end

  describe 'infrastructure config' do
    describe '.max_threads' do
      it 'defaults to 6' do
        ENV.delete('MAX_THREADS')
        expect(config.max_threads).to eq(6)
      end

      it 'returns configured value' do
        ENV['MAX_THREADS'] = '12'
        expect(config.max_threads).to eq(12)
      end
    end

    describe '.aws_region' do
      it 'defaults to eu-west-2' do
        ENV.delete('AWS_REGION')
        expect(config.aws_region).to eq('eu-west-2')
      end
    end

    describe '.allow_missing_migration_files' do
      it 'defaults to true' do
        ENV.delete('ALLOW_MISSING_MIGRATION_FILES')
        expect(config.allow_missing_migration_files).to be true
      end

      it 'returns false when set to false' do
        ENV['ALLOW_MISSING_MIGRATION_FILES'] = 'false'
        expect(config.allow_missing_migration_files).to be false
      end
    end

    describe '.check_query_count?' do
      after { config.instance_variable_set(:@excess_query_threshold, 200) }

      it 'returns false when threshold is 0' do
        ENV.delete('EXCESS_QUERY_THRESHOLD')
        # Reset memoized value
        config.instance_variable_set(:@excess_query_threshold, nil)
        expect(config.check_query_count?).to be false
      end

      it 'returns true when threshold is positive' do
        ENV['EXCESS_QUERY_THRESHOLD'] = '50'
        config.instance_variable_set(:@excess_query_threshold, nil)
        expect(config.check_query_count?).to be true
      end
    end
  end

  describe 'service context' do
    describe '.service' do
      it 'defaults to uk' do
        ENV.delete('SERVICE')
        expect(config.service).to eq('uk')
      end

      it 'returns configured service' do
        ENV['SERVICE'] = 'xi'
        expect(config.service).to eq('xi')
      end
    end

    describe '.uk?' do
      it 'returns true when service is uk' do
        ENV['SERVICE'] = 'uk'
        expect(config.uk?).to be true
      end

      it 'returns false when service is xi' do
        ENV['SERVICE'] = 'xi'
        expect(config.uk?).to be false
      end
    end

    describe '.xi?' do
      it 'returns true when service is xi' do
        ENV['SERVICE'] = 'xi'
        expect(config.xi?).to be true
      end

      it 'returns false when service is uk' do
        ENV['SERVICE'] = 'uk'
        expect(config.xi?).to be false
      end
    end

    describe '.currency' do
      it 'returns GBP for uk service' do
        ENV['SERVICE'] = 'uk'
        expect(config.currency).to eq('GBP')
      end

      it 'returns EUR for xi service' do
        ENV['SERVICE'] = 'xi'
        expect(config.currency).to eq('EUR')
      end
    end

    describe '.environment' do
      it 'returns a StringInquirer wrapping the ENVIRONMENT var' do
        ENV['ENVIRONMENT'] = 'staging'
        expect(config.environment).to be_a(ActiveSupport::StringInquirer)
        expect(config.environment.staging?).to be true
      end

      it 'defaults to local' do
        ENV.delete('ENVIRONMENT')
        expect(config.environment.to_s).to eq('local')
      end
    end

    describe '.promote_customs_tariff_notes?' do
      it 'returns true in development' do
        ENV['ENVIRONMENT'] = 'development'
        expect(config.promote_customs_tariff_notes?).to be true
      end

      it 'returns true in staging' do
        ENV['ENVIRONMENT'] = 'staging'
        expect(config.promote_customs_tariff_notes?).to be true
      end

      it 'returns false in production' do
        ENV['ENVIRONMENT'] = 'production'
        expect(config.promote_customs_tariff_notes?).to be false
      end

      it 'returns true locally' do
        ENV.delete('ENVIRONMENT')
        expect(config.promote_customs_tariff_notes?).to be true
      end
    end
  end

  describe 'OpenSearch config' do
    describe '.opensearch_host' do
      it 'defaults to docker internal address' do
        ENV.delete('ELASTICSEARCH_URL')
        expect(config.opensearch_host).to eq('http://host.docker.internal:9200')
      end

      it 'returns configured URL' do
        ENV['ELASTICSEARCH_URL'] = 'http://opensearch:9200'
        expect(config.opensearch_host).to eq('http://opensearch:9200')
      end
    end

    describe '.opensearch_debug' do
      it 'defaults to false' do
        ENV.delete('OPENSEARCH_DEBUG')
        expect(config.opensearch_debug).to be false
      end

      it 'returns true when enabled' do
        ENV['OPENSEARCH_DEBUG'] = 'true'
        expect(config.opensearch_debug).to be true
      end
    end

    describe '.opensearch_configuration' do
      it 'returns a hash with host and log keys' do
        ENV['ELASTICSEARCH_URL'] = 'http://search:9200'
        ENV.delete('OPENSEARCH_DEBUG')
        expect(config.opensearch_configuration).to eq(
          host: 'http://search:9200',
          log: false,
        )
      end
    end
  end

  describe 'Slack config' do
    describe '.slack_channel' do
      it 'defaults to #tariffs-etl' do
        ENV.delete('SLACK_CHANNEL')
        expect(config.slack_channel).to eq('#tariffs-etl')
      end
    end

    describe '.slack_username' do
      it 'defaults to Trade Tariff Backend' do
        ENV.delete('SLACK_USERNAME')
        expect(config.slack_username).to eq('Trade Tariff Backend')
      end
    end

    describe '.slack_failures_enabled?' do
      it 'defaults to false' do
        ENV.delete('SLACK_FAILURES_ENABLED')
        expect(config.slack_failures_enabled?).to be false
      end

      it 'returns true when enabled' do
        ENV['SLACK_FAILURES_ENABLED'] = 'true'
        expect(config.slack_failures_enabled?).to be true
      end
    end

    describe '.slack_failures_channel' do
      it 'defaults to #production-alerts' do
        ENV.delete('SLACK_FAILURES_CHANNEL')
        expect(config.slack_failures_channel).to eq('#production-alerts')
      end
    end
  end

  describe 'reporting CDN host' do
    around do |example|
      original_environment = ENV['ENVIRONMENT']
      original_reporting_cdn_host = ENV['REPORTING_CDN_HOST']
      example.run
    ensure
      ENV['ENVIRONMENT'] = original_environment
      ENV['REPORTING_CDN_HOST'] = original_reporting_cdn_host
    end

    context 'when REPORTING_CDN_HOST is set' do
      before do
        ENV['ENVIRONMENT'] = 'production'
        ENV['REPORTING_CDN_HOST'] = 'https://custom.example.com'
      end

      it 'prefers the explicit environment variable' do
        expect(config.reporting_cdn_host).to eq('https://custom.example.com')
      end
    end

    context 'when ENVIRONMENT is production' do
      before do
        ENV['ENVIRONMENT'] = 'production'
        ENV.delete('REPORTING_CDN_HOST')
      end

      it 'returns the production reporting host' do
        expect(config.reporting_cdn_host).to eq('https://reporting.trade-tariff.service.gov.uk')
      end
    end

    context 'when ENVIRONMENT is staging' do
      before do
        ENV['ENVIRONMENT'] = 'staging'
        ENV.delete('REPORTING_CDN_HOST')
      end

      it 'returns the staging reporting host' do
        expect(config.reporting_cdn_host).to eq('https://reporting.staging.trade-tariff.service.gov.uk')
      end
    end

    context 'when ENVIRONMENT is development' do
      before do
        ENV['ENVIRONMENT'] = 'development'
        ENV.delete('REPORTING_CDN_HOST')
      end

      it 'returns the development reporting host' do
        expect(config.reporting_cdn_host).to eq('https://reporting.dev.trade-tariff.service.gov.uk')
      end
    end
  end

  describe 'alcohol coercion' do
    describe '.alcohol_coercian_starts_from' do
      it 'defaults to 2022-01-01' do
        ENV.delete('ALCOHOL_COERCIAN_STARTS_FROM')
        expect(config.alcohol_coercian_starts_from).to eq('2022-01-01')
      end
    end

    describe '.excise_alcohol_coercian_starts_from' do
      before { config.instance_variable_set(:@excise_alcohol_coercian_starts_from, nil) }

      it 'returns a parsed Date' do
        ENV.delete('ALCOHOL_COERCIAN_STARTS_FROM')
        expect(config.excise_alcohol_coercian_starts_from).to eq(Date.new(2022, 1, 1))
      end
    end
  end

  describe 'AI / OpenAI config' do
    describe '.ai_model' do
      it 'defaults to gpt-5.2' do
        ENV.delete('AI_MODEL')
        expect(config.ai_model).to eq('gpt-5.2')
      end
    end

    describe '.openai_api_timeout' do
      it 'defaults to 180' do
        ENV.delete('OPENAI_API_TIMEOUT')
        expect(config.openai_api_timeout).to eq(180)
      end
    end

    describe '.openai_api_open_timeout' do
      it 'defaults to 60' do
        ENV.delete('OPENAI_API_OPEN_TIMEOUT')
        expect(config.openai_api_open_timeout).to eq(60)
      end
    end

    describe '.openai_api_base_url' do
      it 'defaults to openai API' do
        ENV.delete('OPENAI_API_BASE_URL')
        expect(config.openai_api_base_url).to eq('https://api.openai.com/v1')
      end
    end

    describe '.openai_model_pricing' do
      it 'loads reviewed model pricing from application config' do
        expect(config.openai_model_pricing).to include(
          'gpt-5.6' => {
            'input_per_million_tokens' => 5.0,
            'cached_input_per_million_tokens' => 0.5,
            'output_per_million_tokens' => 30.0,
            'cache_write_input_multiplier' => 1.25,
            'long_context_input_token_threshold' => 272_000,
            'long_context_input_multiplier' => 2.0,
            'long_context_output_multiplier' => 1.5,
          },
          'gpt-5.6-terra' => {
            'input_per_million_tokens' => 2.5,
            'cached_input_per_million_tokens' => 0.25,
            'output_per_million_tokens' => 15.0,
            'cache_write_input_multiplier' => 1.25,
            'long_context_input_token_threshold' => 272_000,
            'long_context_input_multiplier' => 2.0,
            'long_context_output_multiplier' => 1.5,
          },
          'gpt-5.6-luna' => {
            'input_per_million_tokens' => 1.0,
            'cached_input_per_million_tokens' => 0.1,
            'output_per_million_tokens' => 6.0,
            'cache_write_input_multiplier' => 1.25,
            'long_context_input_token_threshold' => 272_000,
            'long_context_input_multiplier' => 2.0,
            'long_context_output_multiplier' => 1.5,
          },
          'gpt-5.4' => {
            'input_per_million_tokens' => 2.5,
            'cached_input_per_million_tokens' => 0.25,
            'output_per_million_tokens' => 15.0,
          },
          'gpt-4.1-mini-2025-04-14' => {
            'input_per_million_tokens' => 0.4,
            'cached_input_per_million_tokens' => 0.1,
            'output_per_million_tokens' => 1.6,
          },
          'text-embedding-3-small' => {
            'input_per_million_tokens' => 0.02,
          },
        )
      end
    end
  end

  describe 'goods nomenclature config' do
    describe '.goods_nomenclature_label_page_size' do
      it 'defaults to 10' do
        ENV.delete('GOODS_NOMENCLATURE_LABEL_PAGE_SIZE')
        expect(config.goods_nomenclature_label_page_size).to eq(10)
      end

      it 'returns configured value' do
        ENV['GOODS_NOMENCLATURE_LABEL_PAGE_SIZE'] = '25'
        expect(config.goods_nomenclature_label_page_size).to eq(25)
      end
    end
  end

  describe 'Green Lanes config' do
    describe '.green_lanes_api_keys' do
      it 'defaults to empty JSON object' do
        ENV.delete('GREEN_LANES_API_KEYS')
        expect(config.green_lanes_api_keys).to eq('{}')
      end
    end

    describe '.green_lanes_notify_measure_updates' do
      it 'defaults to false' do
        ENV.delete('GREEN_LANES_NOTIFY_MEASURE_UPDATES')
        expect(config.green_lanes_notify_measure_updates).to be false
      end

      it 'returns true when enabled' do
        ENV['GREEN_LANES_NOTIFY_MEASURE_UPDATES'] = 'true'
        expect(config.green_lanes_notify_measure_updates).to be true
      end
    end

    describe '.cupid_team_to_emails' do
      it 'returns an empty array when the env var is not set' do
        ENV.delete('CUPID_TEAM_TO_EMAILS')
        expect(config.cupid_team_to_emails).to eq([])
      end

      it 'returns a single-element array for one address' do
        ENV['CUPID_TEAM_TO_EMAILS'] = 'cupid@example.com'
        expect(config.cupid_team_to_emails).to eq(['cupid@example.com'])
      end

      it 'splits a comma-separated list into an array' do
        ENV['CUPID_TEAM_TO_EMAILS'] = 'a@example.com,b@example.com'
        expect(config.cupid_team_to_emails).to eq(['a@example.com', 'b@example.com'])
      end

      it 'strips whitespace around addresses' do
        ENV['CUPID_TEAM_TO_EMAILS'] = 'a@example.com, b@example.com'
        expect(config.cupid_team_to_emails).to eq(['a@example.com', 'b@example.com'])
      end

      it 'extracts addresses from a JSON hash (AWS Secrets Manager format)' do
        ENV['CUPID_TEAM_TO_EMAILS'] = '{"backend-cupid-team-to-emails":"cupid@example.com"}'
        expect(config.cupid_team_to_emails).to eq(['cupid@example.com'])
      end
    end
  end

  describe 'Redis config' do
    describe '.redis_config' do
      it 'uses REDIS_URL and test redis db in test' do
        ENV['REDIS_URL'] = 'redis://example:6379'
        ENV['TEST_ENV_NUMBER'] = '2'
        expect(config.redis_config).to eq(url: 'redis://example:6379', db: 3, id: nil)
      end
    end

    describe '.sidekiq_redis_config' do
      it 'prefers SIDEKIQ_REDIS_URL when set' do
        ENV['SIDEKIQ_REDIS_URL'] = 'redis://sidekiq:6379'
        ENV['REDIS_URL'] = 'redis://fallback:6379'
        ENV['TEST_ENV_NUMBER'] = '0'
        expect(config.sidekiq_redis_config).to include(
          url: 'redis://sidekiq:6379',
          db: 1,
          timeout: 5,
          reconnect_attempts: [0.1, 0.5, 1.0],
        )
      end

      it 'falls back to REDIS_URL when SIDEKIQ_REDIS_URL is unset' do
        ENV.delete('SIDEKIQ_REDIS_URL')
        ENV['REDIS_URL'] = 'redis://fallback:6379'
        ENV['TEST_ENV_NUMBER'] = '0'
        expect(config.sidekiq_redis_config[:url]).to eq('redis://fallback:6379')
      end
    end

    describe '.frontend_redis_url' do
      it 'defaults to docker host redis' do
        ENV.delete('FRONTEND_REDIS_URL')
        expect(config.frontend_redis_url).to eq('redis://host.docker.internal:6379')
      end

      it 'returns configured URL' do
        ENV['FRONTEND_REDIS_URL'] = 'redis://frontend:6379'
        expect(config.frontend_redis_url).to eq('redis://frontend:6379')
      end
    end
  end

  describe 'identity secrets' do
    describe '.identity_encryption_secret' do
      it 'reads IDENTITY_ENCRYPTION_SECRET from ENV' do
        ENV['IDENTITY_ENCRYPTION_SECRET'] = 'secret-value'
        expect(config.identity_encryption_secret).to eq('secret-value')
      end
    end

    describe '.identity_api_host' do
      it 'reads IDENTITY_API_HOST from ENV' do
        ENV['IDENTITY_API_HOST'] = 'https://identity.example'
        expect(config.identity_api_host).to eq('https://identity.example')
      end
    end

    describe '.identity_api_key' do
      it 'reads IDENTITY_API_KEY from ENV' do
        ENV['IDENTITY_API_KEY'] = 'api-key'
        expect(config.identity_api_key).to eq('api-key')
      end
    end

    describe '.cognito_user_pool_id' do
      it 'reads COGNITO_USER_POOL_ID from ENV' do
        ENV['COGNITO_USER_POOL_ID'] = 'pool-id'
        expect(config.cognito_user_pool_id).to eq('pool-id')
      end
    end
  end

  describe 'email addresses' do
    describe '.from_email' do
      it 'reads TARIFF_FROM_EMAIL from ENV' do
        ENV['TARIFF_FROM_EMAIL'] = 'from@example.com'
        expect(config.from_email).to eq('from@example.com')
      end
    end

    describe '.admin_email' do
      it 'reads TARIFF_SYNC_EMAIL from ENV' do
        ENV['TARIFF_SYNC_EMAIL'] = 'admin@example.com'
        expect(config.admin_email).to eq('admin@example.com')
      end
    end

    describe '.support_email' do
      it 'reads TARIFF_SUPPORT_EMAIL from ENV' do
        ENV['TARIFF_SUPPORT_EMAIL'] = 'support@example.com'
        expect(config.support_email).to eq('support@example.com')
      end
    end

    describe '.management_email' do
      it 'reads TARIFF_MANAGEMENT_EMAIL from ENV' do
        ENV['TARIFF_MANAGEMENT_EMAIL'] = 'mgmt@example.com'
        expect(config.management_email).to eq('mgmt@example.com')
      end
    end

    describe '.cds_updates_send_email' do
      it 'defaults to false' do
        ENV.delete('CDS_UPDATES_SEND_MAIL')
        expect(config.cds_updates_send_email).to be false
      end

      it 'returns true when enabled' do
        ENV['CDS_UPDATES_SEND_MAIL'] = 'true'
        expect(config.cds_updates_send_email).to be true
      end
    end

    describe '.myott_report_email' do
      it 'reads MYOTT_REPORT_EMAIL from ENV' do
        ENV['MYOTT_REPORT_EMAIL'] = 'myott@example.com'
        expect(config.myott_report_email).to eq('myott@example.com')
      end
    end
  end

  describe 'API tokens and XE credentials' do
    describe '.api_tokens' do
      it 'reads GREEN_LANES_API_TOKENS from ENV' do
        ENV['GREEN_LANES_API_TOKENS'] = 'token-a,token-b'
        expect(config.api_tokens).to eq('token-a,token-b')
      end
    end

    describe '.xe_api_username' do
      it 'reads XE_API_USERNAME from ENV' do
        ENV['XE_API_USERNAME'] = 'xe-user'
        expect(config.xe_api_username).to eq('xe-user')
      end
    end

    describe '.xe_api_password' do
      it 'reads XE_API_PASSWORD from ENV' do
        ENV['XE_API_PASSWORD'] = 'xe-pass'
        expect(config.xe_api_password).to eq('xe-pass')
      end
    end

    describe '.openai_user' do
      it 'defaults to hmrc-ott' do
        ENV.delete('OPENAI_USER')
        expect(config.openai_user).to eq('hmrc-ott')
      end

      it 'returns configured user' do
        ENV['OPENAI_USER'] = 'custom-user'
        expect(config.openai_user).to eq('custom-user')
      end
    end

    describe '.openai_api_key' do
      it 'reads OPENAI_API_KEY from ENV' do
        ENV['OPENAI_API_KEY'] = 'sk-test'
        expect(config.openai_api_key).to eq('sk-test')
      end
    end

    describe '.slack_web_hook_url' do
      it 'reads SLACK_WEB_HOOK_URL from ENV' do
        ENV['SLACK_WEB_HOOK_URL'] = 'https://hooks.slack.example/abc'
        expect(config.slack_web_hook_url).to eq('https://hooks.slack.example/abc')
      end
    end
  end
end

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

    describe '.cds_importer_batch_size' do
      it 'defaults to 100' do
        ENV.delete('CDS_IMPORT_BATCH_SIZE')
        expect(config.cds_importer_batch_size).to eq(100)
      end

      it 'returns configured value as integer' do
        ENV['CDS_IMPORT_BATCH_SIZE'] = '250'
        expect(config.cds_importer_batch_size).to eq(250)
      end
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

      it 'does not cache the threshold across ENV changes' do
        ENV['EXCESS_QUERY_THRESHOLD'] = '50'
        config.instance_variable_set(:@excess_query_threshold, nil)

        expect(config.check_query_count?).to be true

        ENV.delete('EXCESS_QUERY_THRESHOLD')

        expect(config.check_query_count?).to be false
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
  end
end
